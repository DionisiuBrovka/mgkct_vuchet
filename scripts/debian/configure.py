#!/usr/bin/env python3
"""Configuration and first-run bootstrap for the native Debian installer."""
import json
import os
from pathlib import Path
import re
import secrets
import socket
import string
import subprocess
import sys
from urllib.parse import urlencode, urlsplit
from urllib.request import ProxyHandler, Request, build_opener


def parse_origin(value):
    url = urlsplit(value)
    if (url.scheme != 'http' or not url.hostname or url.username or url.password
            or url.path not in ('', '/') or url.query or url.fragment
            or not re.fullmatch(r'[A-Za-z0-9.-]+', url.hostname)):
        raise ValueError('Укажите HTTP-адрес локальной сети без пути: http://192.168.1.10:8090')
    port = url.port or 80
    if not 1024 <= port <= 65535 or port == 8091:
        raise ValueError('Порт приложения: 1024–65535, кроме 8091 (PocketBase). Обычно 8090.')
    return f'http://{url.hostname}:{port}', port


def write_private(path, text):
    temporary = path.with_suffix(path.suffix + '.tmp')
    with open(temporary, 'w', encoding='utf-8', opener=lambda p, flags: os.open(p, flags, 0o600)) as file:
        file.write(text)
    temporary.chmod(0o600)
    temporary.replace(path)


def read_environment(path, allowed=None):
    values = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        match = re.fullmatch(r'([A-Z][A-Z0-9_]*)=(.*)', line)
        if not match:
            raise ValueError(f'Некорректная строка в {path.name}')
        key, value = match.groups()
        if allowed is not None and key not in allowed:
            continue
        if key in values:
            raise ValueError(f'Повторяющийся параметр {key} в {path.name}')
        if value.startswith('"'):
            value = json.loads(value)
        if not isinstance(value, str) or '\n' in value or '\r' in value:
            raise ValueError(f'Некорректный параметр {key}')
        values[key] = value
    return values


def generated_password():
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(8))


def configure(directory, origin, source_env=None):
    path = directory / 'install.env'
    keys = {'PUBLIC_ORIGIN', 'PB_SERVICE_EMAIL', 'PB_SERVICE_PASSWORD',
            'ADMIN_EMAIL', 'ADMIN_PASSWORD'}
    source = read_environment(Path(source_env), {'PUBLIC_ORIGIN'}) if source_env else {}
    existing = path.exists() or (directory / 'install.json').exists()
    requested_origin = origin or ('' if existing else source.get('PUBLIC_ORIGIN', ''))
    if path.exists():
        values = read_environment(path, keys)
        if set(values) != keys:
            raise ValueError('Неполная конфигурация install.env')
        old_origin, old_port = parse_origin(values['PUBLIC_ORIGIN'])
        config = dict(origin=old_origin, port=old_port,
                      service_email=values['PB_SERVICE_EMAIL'],
                      service_password=values['PB_SERVICE_PASSWORD'],
                      admin_email=values['ADMIN_EMAIL'],
                      admin_password=values['ADMIN_PASSWORD'])
    elif (directory / 'install.json').exists():
        config = json.loads((directory / 'install.json').read_text())
    else:
        initial_origin, port = parse_origin(requested_origin)
        service_password = generated_password()
        admin_password = generated_password()
        while admin_password == service_password:
            admin_password = generated_password()
        config = dict(origin=initial_origin, port=port,
                      service_email='service@example.invalid',
                      service_password=service_password,
                      admin_email='admin@example.invalid',
                      admin_password=admin_password)
    if requested_origin:
        new_origin, port = parse_origin(requested_origin)
        if port != config['port']:
            raise ValueError('При обновлении сохраняйте прежний порт приложения.')
        config['origin'] = new_origin
    parse_origin(config['origin'])
    if any('\n' in str(v) or '\r' in str(v) for v in config.values()):
        raise ValueError('Некорректный файл конфигурации')
    values = {'PUBLIC_ORIGIN': config['origin'],
              'PB_SERVICE_EMAIL': config['service_email'],
              'PB_SERVICE_PASSWORD': config['service_password'],
              'ADMIN_EMAIL': config['admin_email'],
              'ADMIN_PASSWORD': config['admin_password']}
    write_private(path, ''.join(f'{key}={json.dumps(value)}\n' for key, value in values.items()))
    environment = {
        'HOST': '0.0.0.0', 'PORT': str(config['port']),
        'STATIC_DIR': '/opt/mgkct/current/public',
        'POCKETBASE_URL': 'http://127.0.0.1:8091',
        'PUBLIC_ORIGIN': config['origin'],
        'PB_SERVICE_EMAIL': config['service_email'],
        'PB_SERVICE_PASSWORD': config['service_password'],
        'NO_PROXY': 'localhost,127.0.0.1,::1',
    }
    write_private(directory / 'app.env', ''.join(f'{k}={json.dumps(v)}\n' for k, v in environment.items()))
    write_private(directory / 'credentials.txt',
                  f"Приложение: {config['origin']}\nПользователь: Завуч\n"
                  f"Начальный пароль: {config['admin_password']}\n\n"
                  f"PocketBase: http://IP-СЕРВЕРА:8091/_/ (замените IP на адрес сервера)\n"
                  f"Email: {config['service_email']}\nПароль: {config['service_password']}\n\n"
                  'Пароль приложения после ручной смены здесь не обновляется.\n'
                  'Сервисный пароль PocketBase используется приложением; меняйте его согласованно с install.env и повторным запуском установки.\n')
    (directory / 'install.json').unlink(missing_ok=True)
    return config


def load_config(directory):
    values = read_environment(directory / 'install.env')
    origin, port = parse_origin(values['PUBLIC_ORIGIN'])
    return dict(origin=origin, port=port, service_email=values['PB_SERVICE_EMAIL'],
                service_password=values['PB_SERVICE_PASSWORD'], admin_email=values['ADMIN_EMAIL'],
                admin_password=values['ADMIN_PASSWORD'])


def pb_request(base, path, body=None, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
    # Provisioning must never send service credentials through an HTTP proxy.
    with build_opener(ProxyHandler({})).open(req, timeout=15) as response:
        return json.load(response)


def bootstrap(directory, base='http://127.0.0.1:8091'):
    config = load_config(directory)
    token = pb_request(base, '/api/collections/_superusers/auth-with-password', {
        'identity': config['service_email'], 'password': config['service_password'],
    })['token']
    marker = directory / 'bootstrap-complete'
    if marker.exists():
        return
    query = urlencode({'filter': f'email = {json.dumps(config["admin_email"])}'})
    existing = pb_request(base, '/api/collections/users/records?' + query, token=token)['items']
    if not existing:
        pb_request(base, '/api/collections/users/records', {
            'email': config['admin_email'], 'password': config['admin_password'],
            'passwordConfirm': config['admin_password'], 'name': 'Завуч',
            'role': 'admin', 'is_active': True, 'auth_version': 1,
        }, token=token)
    elif existing[0].get('role') != 'admin':
        raise ValueError('Начальная учётная запись уже существует с другой ролью.')
    write_private(marker, 'Initial administrator created. Do not rotate on upgrade.\n')


def check_ports(config):
    for port, unit in [(config['port'], 'mgkct-app'), (8091, 'mgkct-pocketbase')]:
        with socket.socket() as sock:
            try:
                sock.bind(('0.0.0.0', port))
            except OSError:
                if subprocess.run(['systemctl', 'is-active', '--quiet', unit]).returncode:
                    raise ValueError(f'Порт {port} занят другой службой. Освободите его перед установкой.')


def main():
    action, directory, *args = sys.argv[1:]
    directory = Path(directory)
    if action == 'configure':
        configure(directory, args[0], args[1] if len(args) > 1 else None)
        return
    config = load_config(directory)
    if action == 'get':
        if args[0] not in ('origin', 'port'):
            raise ValueError('Недопустимый ключ')
        print(config[args[0]])
    elif action == 'ports':
        check_ports(config)
    elif action == 'superuser':
        subprocess.run(['runuser', '-u', 'mgkct-pb', '--', args[0], 'superuser', 'upsert',
                        config['service_email'], config['service_password'],
                        '--dir=/var/lib/mgkct/pb_data', '--automigrate=false'],
                       check=True, cwd='/var/lib/mgkct', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif action == 'bootstrap':
        bootstrap(directory)
    else:
        raise ValueError('Неизвестная команда')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError:
        sys.exit('Ошибка запуска служебной команды. Проверьте права и журнал службы.')
    except Exception as error:
        sys.exit(f'Ошибка настройки: {error}')
