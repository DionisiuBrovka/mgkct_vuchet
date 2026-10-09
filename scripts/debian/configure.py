#!/usr/bin/env python3
"""Configuration and first-run bootstrap for the native Debian installer."""
import json
import os
from pathlib import Path
import re
import secrets
import socket
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


def configure(directory, origin):
    path = directory / 'install.json'
    if path.exists():
        config = json.loads(path.read_text())
        if origin:
            new_origin, port = parse_origin(origin)
            if port != config['port']:
                raise ValueError('При обновлении сохраняйте прежний порт приложения.')
            config['origin'] = new_origin
    else:
        origin, port = parse_origin(origin)
        config = dict(origin=origin, port=port,
                      service_email='service@example.invalid',
                      service_password=secrets.token_urlsafe(36),
                      admin_email='admin@example.invalid',
                      admin_password=secrets.token_urlsafe(24))
    parse_origin(config['origin'])
    if any('\n' in str(v) or '\r' in str(v) for v in config.values()):
        raise ValueError('Некорректный файл конфигурации')
    write_private(path, json.dumps(config, ensure_ascii=False, indent=2) + '\n')
    environment = {
        'HOST': '0.0.0.0', 'PORT': str(config['port']),
        'STATIC_DIR': '/opt/mgkct/current/public',
        'POCKETBASE_URL': 'http://127.0.0.1:8091',
        'PUBLIC_ORIGIN': config['origin'],
        'PB_SERVICE_EMAIL': config['service_email'],
        'PB_SERVICE_PASSWORD': config['service_password'],
        'NO_PROXY': 'localhost,127.0.0.1,::1',
    }
    def quote(value):
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
    write_private(directory / 'app.env', ''.join(f'{k}={quote(v)}\n' for k, v in environment.items()))
    write_private(directory / 'credentials.txt',
                  f"Приложение: {config['origin']}\nПользователь: Завуч\n"
                  f"Начальный пароль: {config['admin_password']}\n\n"
                  f"PocketBase: http://127.0.0.1:8091/_/ (через SSH-туннель)\n"
                  f"Email: {config['service_email']}\nПароль: {config['service_password']}\n\n"
                  'Пароль приложения после ручной смены здесь не обновляется.\n'
                  'Сервисный пароль PocketBase используется приложением; меняйте его согласованно с install.json и повторным запуском установки.\n')
    return config


def pb_request(base, path, body=None, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
    # Provisioning must never send service credentials through an HTTP proxy.
    with build_opener(ProxyHandler({})).open(req, timeout=15) as response:
        return json.load(response)


def bootstrap(directory, base='http://127.0.0.1:8091'):
    config = json.loads((directory / 'install.json').read_text())
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
                sock.bind(('0.0.0.0' if unit == 'mgkct-app' else '127.0.0.1', port))
            except OSError:
                if subprocess.run(['systemctl', 'is-active', '--quiet', unit]).returncode:
                    raise ValueError(f'Порт {port} занят другой службой. Освободите его перед установкой.')


def main():
    action, directory, *args = sys.argv[1:]
    directory = Path(directory)
    if action == 'configure':
        configure(directory, args[0])
        return
    config = json.loads((directory / 'install.json').read_text())
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
