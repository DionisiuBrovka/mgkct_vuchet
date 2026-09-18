# Финальная приёмка

Дата: 2026-09-18. Снимок проверен после `cc21d86`; финальные исправления этой
приёмки добавляют release-binary в `scripts/check.sh`, удаляют устаревший
`docker-compose.yml` и синхронизируют статусы задач.

| Требование §21 | Доказательство | Результат |
|---|---|---|
| Чистая новая схема PB | `scripts/fetch-pocketbase.sh` (0.40.1 + SHA) и `data/pocketbase/tests/test_report_storage.py` | пройдено локально; CI дефект clean checkout исправлен, ожидается повторный run |
| Справочники subject/group и relation assignments | `task/data_schema.md`, schema test | пройдено локально |
| ФИО без двойного ввода | Shelf directory/profile DTO и client tests | пройдено локально |
| Клиент не знает PB; Shelf владеет правами/валидацией | `client/lib`, server API tests и raw-PB ограничения | пройдено локально |
| Документированный API согласован с клиентом | `task/api_contract.md`, server/client tests | пройдено локально |
| Вход, restore и logout | server API test и Flutter session tests | пройдено локально |
| Цикл преподавателя; дробные часы без округления | command tests, `decimal_input_test.dart`, `report_client_test.dart` | пройдено локально |
| Поиск, просмотр, confirm/return завучем | server lifecycle test и Flutter review tests | пройдено локально |
| Прямым запросом нельзя обойти права | изолированный server API test, PB schema test | пройдено локально |
| Голубой Web UI и LAN | release Web build, Podman self-test и обычный `deploy.sh up` | health прошёл через `192.168.111.11`; второе LAN-устройство не проверено |
| Тесты, анализ, release-сборки и master-check | `bash scripts/check.sh` — exit 0: schema, format, analyze, server/client tests, server binary, Web build | пройдено локально |
| CI исполняет тот же набор | `.github/workflows/check.yml` вызывает `scripts/check.sh` и тот же PB bootstrap | remote master-check зелёный; исправлено создание artifact directory, нужен итоговый run/artifact |
| Воспроизводимый deploy и health | `bash scripts/deploy.sh --self-test` — exit 0, Podman 5.8.4 | пройдено локально; restart app и cleanup подтверждены |
| Очистка репозитория и актуальные docs | `cleanup_audit.md`, `README.md`, `AGENTS.md`, `.env.example`, `git ls-files` audit | пройдено локально |
| Запуск по документации на чистой среде | изолированный Podman self-test без `.env` и данных | пройдено локально; полный ручной цикл на отдельной машине не выполнен |

## Выполненные команды

```text
bash -n scripts/deploy.sh                         exit 0
sh -n entrypoint.sh                                exit 0
bash scripts/check.sh                              exit 0
bash scripts/deploy.sh --help                      exit 0
bash scripts/deploy.sh --self-test                 exit 0
git diff --check                                   exit 0
```

`scripts/check.sh` не запускает browser E2E: это сознательное исключение по
прямому решению владельца. Частичный `e2e/smoke.mjs` оставлен в истории и не
считается приёмочным доказательством.

## Открытые условия приёмки

Финальная приёмка не может быть объявлена полностью завершённой, пока не будут
получены два внешних факта: зелёный GitHub Actions run с загруженным artifact и
ручной цикл на втором LAN-устройстве. Полный browser E2E также исключён
владельцем и остаётся зафиксированным отклонением Task 23. Ни один из этих
пунктов не заменён предположением или локальным unit-тестом.
