# Стратегия тестов и изолированных стендов

Статус: нормативное решение Task 07 от 2026-09-17. Основана на API contract,
PB 0.40.1 и фактической среде: Flutter 3.44.8/Dart 3.12.2, Node 24.18.0.
Ни один тест не использует рабочий `PB_DATA_DIR`, реальные учётные записи или
секреты владельца.

## Пирамида и матрица

| Требование | Уровень | Владелец | Сценарий | Итоговая команда |
|---|---|---|---|---|
| canonical decimal, `0.1+0.2`, long fraction, >2^53 | Dart unit | 12, 14 | parser/BigInt/format, 422 | `cd server && dart test`; `cd client && flutter test` |
| period Europe/Minsk, август, empty/zero policy | Dart unit + service | 12, 13, 16 | injected clock, boundary dates, substitution-only | server/client tests |
| schema, indexes, PB access, immutable references, sessions | PB integration | 09 | fresh PB migration/hooks, direct user denial | `python3 -m unittest discover -s data/pocketbase/tests -v` |
| login/restore/logout/block/role, Origin/CSRF | Shelf integration | 11, 15 | cookie registry, 401 vs 502, two sessions | `cd server && dart test` |
| read, totals, exact storage, CAS, rollback | Shelf+PB integration | 10, 12, 13 | concurrent first create/save/status conflict | `cd server && dart test` |
| DTO mapping/API errors | client unit | 14 | strict DTO and error envelope | `cd client && flutter test` |
| login/restore/router/teacher/admin UI | widget/Cubit | 15–20 | loading/empty/retry/form preservation/filter/confirmed read-only | `cd client && flutter test` |
| user journey in built Web | browser E2E | 23 | teacher submit, admin filter/review/return/confirm, session restore | pinned Playwright suite |
| layout at target widths | browser manual+automated capture | 21 | Russian blue UI, narrow/wide viewport | Playwright + visual protocol |

Старые migration-backfill tests не переносятся: Task 09 заменяет их baseline
schema tests. Смысл существующих role/CAS/rollback/form-preservation tests
сохраняется в новой contract terminology.

## Изолированный стенд

Каждый schema/server/E2E run создаёт уникальный `mktemp -d` directory для PB
data, отдельный service credentials и dynamic loopback ports (bind port `0`,
затем передать найденный port дочернему процессу). Cleanup в `finally` останавливает
Shelf/PB/browser и удаляет **только** созданный directory. Failure, timeout,
занятый port и interrupted test также выполняют cleanup; cleanup failure делает
run failed.

Стандартные fixtures: два teachers с одинаковым `name` и разными IDs, один
admin, один inactive teacher, subject/group/assignment для 2026/2027, fixed
server clock и independent report per test. Test создаёт свои records, не
наследует mutable state от другого test. Passwords — generated temporary values,
не печатаются в output. Parallel processes используют собственные dirs/ports.

PB schema test вызывает только local binary `data/pocketbase/pocketbase` 0.40.1
с baseline migration. Shelf integration поднимает этот same fixture, получает
HTTP cookie как browser, а не PB bearer. E2E использует release `flutter build
web --release`, Shelf static serving и temporary PB; это проверяет ровно
deployable topology, но не production data/host.

## Browser E2E

Task 23 добавляет pinned `@playwright/test` dev dependency и lockfile, запускает
Chromium из локального package cache/explicit browser install, не полагается на
системный браузер. Playwright выбран потому, что проверяет реальные cookie,
navigation, viewport и built static Web; он не дублирует десятки unit cases.
Если browser binary недоступен, script сообщает prerequisite и завершается
ненулевым кодом — пропуск не считается PASS.

E2E minimum: public directory/login; reload restores session; inactive/revoked
session returns login; teacher saves then submits exact decimal/substitution;
admin filters name+status, views submitted, returns, then confirms; direct
forbidden action fails; final screen is read-only. Task 21 owns visual capture,
Task 23 owns functional journey and cleanup.

## Release gates

Task 22 creates `scripts/check.sh`; it must run, in this order, and fail fast
with a final failure summary/nonzero exit:

```text
tool/prerequisite check
dart format --set-exit-if-changed server
flutter format --set-exit-if-changed client
python PB schema tests
server dart analyze + dart test + compile exe
client flutter analyze + flutter test + build web --release
isolated health/smoke; after Task 23, Playwright E2E
```

No master-script ↔ E2E cycle: Task 22 defines a non-E2E baseline and accepts an
optional E2E command; Task 23 implements it and wires it into the script. CI
Task 26 invokes the same script, not a divergent list. Task 25 deploy QA is
separate from test fixture and never deletes a volume.

## Ownership sequence

09 schema fixtures/rules; 10 storage concurrency; 11 auth/HTTP integration;
12 query+clock+decimal service; 13 command transitions; 14 DTO client tests;
15–20 feature tests; 21 visual protocol; 22 orchestration; 23 browser E2E;
24–28 rerun applicable gates on final artifact. A test belongs to the earliest
task that can prove it, preventing implementation from silently leaving a
requirement for final acceptance.

## Verification of this strategy

Manual trace 2026-09-17 followed CAS and session restore from fixture through
temporary PB, Shelf, cookie/browser and cleanup; two concurrent runs differ by
temp dir and dynamic port. Existing tests were inspected: server has one shared
fixture, PB tests are legacy migration-oriented, and client lacks restore/filter/
substitution coverage. The specified matrix closes those gaps without testing
the future client from schema tests.
