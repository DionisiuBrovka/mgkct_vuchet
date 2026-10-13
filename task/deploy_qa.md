# Проверка единого Debian-деплоя — 2026-10-13

Предыдущий контейнерный протокол заменён нативной установкой через
`sudo bash scripts/deploy.sh` на Debian 13 amd64.

- `bash scripts/check.sh` — успешно: installer/PocketBase/server/client тесты,
  анализ, сборка Shelf и Flutter Web, проверка пробелов.
- Шесть тестов установщика прошли на временной конфигурации и базе PocketBase:
  адрес и порт, пароли по 8 символов, неизменность паролей при обновлении,
  перенос `install.json`, права 0600, первый и повторный bootstrap.
- `bash -n scripts/deploy.sh`, `python3 -m py_compile scripts/debian/configure.py`
  и `git diff --check` — успешно.
- Реестр `docker.io/library/dart:3.12.2-sdk` ответил на проверку manifest.
  Образ Flutter 3.44.8 в прежнем реестре отсутствует; Dockerfile использует
  проверяемый архив Flutter 3.44.8, как и Debian-установщик.
- `podman build --pull=always -f Dockerfile -t mgkct-app:refactor-check .` —
  успешно: архив Flutter прошёл SHA-256, собраны Flutter Web, Dart executable
  и итоговый образ.

Нативная установка на физическом сервере владельца, его firewall и доступность
со второго компьютера локальной сети в этом изменении не проверялись.
Предыдущий изолированный Debian 13/systemd прогон описан в
`task/debian_install_qa.md`; он выполнен до этого рефакторинга.
