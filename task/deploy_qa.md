# Deploy QA

2026-09-18, local Linux x86_64 / Podman 5.8.4:

- `bash scripts/deploy.sh --self-test` — exit 0: собраны фиксированные Web,
  Shelf и PocketBase images; создан отдельный network/volume; health Shelf и
  PB проверен до и после restart app; временные containers/network/volume
  очищены.
- `bash -n scripts/deploy.sh`, `sh -n entrypoint.sh` и `git diff --check` —
  exit 0.
- Второе LAN-устройство не было доступно: это не отмечено как выполненная
  ручная проверка. PB self-test не публиковался на host port.

Обычный запуск: скопировать `.env.example` в `.env`, заменить пароль и
`PUBLIC_ORIGIN`, затем `bash scripts/deploy.sh up`. `down` сохраняет volume.
