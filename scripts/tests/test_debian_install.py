"""Installer checks use disposable config and PocketBase, never host services."""
import importlib.util
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('debian_config', ROOT / 'scripts/debian/configure.py')
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class ConfigurationTest(unittest.TestCase):
    def test_origin_validation(self):
        self.assertEqual(config.parse_origin('http://192.168.1.10:8090/'), ('http://192.168.1.10:8090', 8090))
        for origin in ['https://school:8090', 'http://user:pass@school:8090',
                       'http://school:8091', 'http://school', 'http://school:8090/api',
                       'http://school:8090?q=x', 'http://school:8090#x', 'http://school:99999']:
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                config.parse_origin(origin)

    def test_upgrade_preserves_credentials_and_private_permissions(self):
        with tempfile.TemporaryDirectory(prefix='mgkct-install-config-') as temp:
            directory = Path(temp)
            first = config.configure(directory, 'http://192.168.1.10:8090')
            second = config.configure(directory, '')
            self.assertEqual(first, second)
            updated = config.configure(directory, 'http://school:8090')
            self.assertEqual(first['service_password'], updated['service_password'])
            self.assertEqual(first['admin_password'], updated['admin_password'])
            self.assertNotEqual(first['admin_password'], first['service_password'])
            for name in ['install.json', 'app.env', 'credentials.txt']:
                self.assertEqual((directory / name).stat().st_mode & 0o777, 0o600)
            self.assertIn('PUBLIC_ORIGIN="http://school:8090"', (directory / 'app.env').read_text())
            with self.assertRaises(ValueError):
                config.configure(directory, 'http://school:9090')
            self.assertEqual(json.loads((directory / 'install.json').read_text()), updated)

    def test_conflicting_port_fails_without_stopping_services(self):
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            with patch.object(config.subprocess, 'run') as run:
                run.return_value.returncode = 3
                with self.assertRaises(ValueError):
                    config.check_ports({'port': sock.getsockname()[1]})
                self.assertEqual(run.call_args.args[0][:3], ['systemctl', 'is-active', '--quiet'])

    def test_help_needs_no_root_or_podman(self):
        result = subprocess.run(['bash', str(ROOT / 'scripts/deploy.sh'), 'debian', '--help'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Debian 13', result.stdout)


class BootstrapTest(unittest.TestCase):
    def test_real_schema_first_admin_and_repeat_without_password_reset(self):
        with tempfile.TemporaryDirectory(prefix='mgkct-install-pb-') as temp:
            directory = Path(temp)
            initial = config.configure(directory, 'http://school:8090')
            binary = ROOT / 'data/pocketbase/pocketbase'
            flags = [f'--dir={directory / "data"}',
                     f'--migrationsDir={ROOT / "data/pocketbase/pb_migrations"}', '--automigrate=false']
            for command in [['migrate', 'up'], ['superuser', 'upsert', initial['service_email'], initial['service_password']]]:
                subprocess.run([str(binary), *command, *flags], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            with socket.socket() as sock:
                sock.bind(('127.0.0.1', 0))
                port = sock.getsockname()[1]
            base = f'http://127.0.0.1:{port}'
            with open(directory / 'pb.log', 'w') as log:
                process = subprocess.Popen([str(binary), 'serve', *flags,
                                            f'--hooksDir={ROOT / "data/pocketbase/pb_hooks"}',
                                            f'--http=127.0.0.1:{port}'], stdout=log, stderr=log)
                try:
                    for attempt in range(100):
                        try:
                            config.pb_request(base, '/api/health')
                            break
                        except OSError:
                            if attempt == 99:
                                raise
                            time.sleep(.05)
                    config.bootstrap(directory, base)
                    user = config.pb_request(base, '/api/collections/users/auth-with-password',
                                             {'identity': initial['admin_email'], 'password': initial['admin_password']})['record']
                    self.assertEqual(user['role'], 'admin')
                    self.assertTrue(user['is_active'])
                    self.assertEqual(user['name'], 'Завуч')
                    self.assertTrue((directory / 'bootstrap-complete').exists())
                    # Simulate retry after account creation but before writing the marker.
                    (directory / 'bootstrap-complete').unlink()
                    config.bootstrap(directory, base)
                    altered = dict(initial, admin_password='Must-not-replace-existing-password-123')
                    (directory / 'install.json').write_text(json.dumps(altered))
                    config.bootstrap(directory, base)
                    config.pb_request(base, '/api/collections/users/auth-with-password',
                                      {'identity': initial['admin_email'], 'password': initial['admin_password']})
                finally:
                    process.terminate()
                    process.wait(timeout=10)


if __name__ == '__main__':
    unittest.main()
