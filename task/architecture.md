# Целевая архитектура и порядок замены

Статус: нормативное решение Task 01 от 2026-09-17. Этот документ определяет
границы новой версии; он не фиксирует DTO, схему, формат десятичных часов или
механизм сессии — их владельцы перечислены ниже. При конфликте приоритет имеет
[product_spec.md](product_spec.md), затем этот документ.

## Целевая карта

```text
Flutter Web (`client/`)
  screens/widgets ──> Cubit ──> repository ──> typed API client ── HTTP/JSON ──┐
                                                                                │
Dart Shelf (`server/`)                                                         │
  route + DTO ──> request actor ──> application service ──> store ── PB API ──┤
                                                                                │
PocketBase / SQLite (`data/pocketbase/`)                                      │
  schema, direct-access rules, indexes, transaction/CAS hook <─────────────────┘
```

Стрелки показывают допустимое направление зависимостей. Модуль слева не
импортирует и не вызывает модуль справа в обратном направлении. В частности,
Flutter не импортирует PocketBase SDK и не знает названий его коллекций или
полей; PocketBase hook не реализует HTTP API, роли или жизненный цикл отчёта.

### Ответственность слоёв

| Слой | Владеет | Не владеет |
|---|---|---|
| Flutter Web | экраном, маршрутом, локальным вводом, состояниями loading/error/empty, предварительным разбором и предпросмотром итогов | правами, окончательной валидацией, статусами, итогами, доступом к PocketBase |
| Shelf HTTP/DTO | маршрутом, разбором HTTP/JSON, единым error response, извлечением сессии и формированием DTO | SQL/PocketBase-деталями и состоянием конкретного экрана |
| Shelf application service | проверкой актёра и роли, политикой периода, статусными переходами, окончательной нормализацией/валидацией, точными итогами, orchestration чтения и записи | заголовками HTTP, виджетами и физической транзакцией SQLite |
| PocketBase adapter/store | вызовами PB SDK, преобразованием record ↔ внутренние данные, сервисной аутентификацией и переводом ошибок хранилища | публичными DTO, решением о правах/переходах и подсчётом итогов |
| PocketBase/SQLite | нормализованной схемой, ссылочной целостностью, индексами, запретом прямого доступа и атомарным CAS полного отчёта | доверенным пользовательским API и дублируемой бизнес-политикой |

Единственный источник истины для бизнес-правил — application service Shelf.
Единственный источник истины для статуса — запись `teaching_reports`; строки
часов и замены не дублируют статус. PocketBase обеспечивает, что согласованная
команда либо сохранит полный агрегат с ожидаемой ревизией, либо не изменит его.
Это не переносит в hook проверку, имеет ли учитель право редактировать отчёт.

## Операции: поток, владельцы и тесты

Ниже «итоги» означает окончательные точные итоги ответа/проверки; локальный
предпросмотр допускается только как удобство и не является источником истины.

| Операция | Клиентский путь | Shelf владелец прав и правил | Запись/чтение PB | Владелец тестов |
|---|---|---|---|---|
| health | API client → экран/операторский вызов | публичный health route проверяет доступность PB | adapter вызывает health | 11, 22, 25 |
| список входа | LoginScreen → AuthCubit → AuthRepository | публичный directory route отдаёт только ID и штатное имя | users, без email/role | 11, 15 |
| вход/восстановление/выход | AuthCubit и session repository; router реагирует только на подтверждённое состояние | auth service проверяет учётную запись, активность, роль и сессию на каждом защищённом запросе | users и выбранный в Task 04 механизм сессии | 04, 11, 15 |
| месяцы преподавателя | teacher periods Cubit → teacher repository | actor обязан совпадать с teacher; период выводится серверной политикой | reports и assignments по чистой схеме | 03, 12, 16 |
| полный отчёт | editor/review Cubit → общий report repository | teacher читает только свой, admin — любой; сервис собирает агрегат и считает итоги | reports, entries, substitutions, assignments, subjects, groups | 12, 17, 20 |
| save draft | editor Cubit сохраняет raw input при ошибке | только owner и только `draft`; нормализует, валидирует, считает, проверяет revision | одна CAS-транзакция полного агрегата | 10, 13, 17 |
| submit | editor Cubit | только owner и только `draft`; тот же атомарный write плюс `draft → submitted`, запрещает пустой отчёт | одна CAS-транзакция | 10, 13, 17 |
| confirm/return | review Cubit | только admin и только `submitted`; проверяет revision и переход | одна CAS-транзакция статуса/агрегата | 10, 13, 20 |

Проверка на маршруте или скрытая кнопка не заменяют service-проверку. Любой
защищённый маршрут сначала получает свежий request-local actor, затем передаёт
его в application service. Никакой actor, токен или роль не хранятся в global
переменной сервера между запросами.

## Целевая модульная граница

### Клиент

После Task 14 общие API-модели, маппинг DTO, ошибки и HTTP-клиент живут в
`client/lib/core/` или равноценном общем слое; репозитории зависят только от
него. Общий report DTO не живёт в `features/teacher`: admin и teacher получают
его через общий слой. Конкретные feature имеют однонаправленную зависимость:

```text
features/auth, features/teacher, features/admin
              ↓
  shared presentation (тема, общие widgets; без feature-логики)
              ↓
 core API/models/errors/session transport
```

`app.dart` остаётся composition root маршрутизации и providers. DI через
`get_it` собирает зависимости, но не содержит бизнес-решений. Cubit не делает
HTTP-вызовы напрямую: он управляет состоянием и вызывает repository. Экран не
меняет report DTO в обход Cubit. Freezed применяется для неизменяемых моделей и
состояний; сгенерированный код производен от handwritten model и не редактируется
вручную.

Существующая полезная основа сохраняется: `ApiService` уже работает через HTTP,
`go_router` обеспечивает ролевую навигацию, `flutter_bloc` — состояния, а
`get_it` — composition. Существующая зависимость
`features/admin/cubit/admin_cubit.dart` →
`features/teacher/repository/teaching_report_repository.dart` должна исчезнуть
в Task 14 вместе с переносом общего report repository/model в нейтральный слой.

### Сервер

Task 11 разделяет нынешний монолитный `server/lib/server.dart` на небольшие
модули (точные имена — реализационное решение, не обязательный новый каталог):

```text
server/lib/
  server.dart                 composition root: middleware + route registry
  src/http/                   route handlers, JSON/DTO, error mapping
  src/auth/                   request actor and session-facing service
  src/reports/                query/command application services
  src/storage/                PocketBase adapter and report-write port
```

Допустимы меньшее число файлов, если сохраняются эти границы; не требуется
вводить отдельный framework, CQRS-слой или generic repository. HTTP handler
вызывает service и преобразует только transport-specific значения. Service
работает с доменными/внутренними значениями, а adapter изолирует
`RecordModel`, `ClientException`, имена коллекций и PB SDK. Поэтому client DTO
не передаётся напрямую в hook и `RecordModel` не покидает storage boundary.

Существующие `jsonBody`, единый JSON response, CORS/error middleware и static
hosting Shelf полезны, но сейчас сосуществуют с маршрутами и авторизацией в
одном файле; их следует сохранить по смыслу и вынести по границам в Task 11.
`ReportService` и `PocketBaseStore` служат доказательством нужной развязки, а
не контрактом новой версии. Static Web остаётся допустимо раздавать Shelf;
решение о runtime и CORS конкретизирует Task 08.

### Данные

`data/pocketbase/` остаётся владельцем лишь воспроизводимого PB-окружения:
миграций чистой схемы, schema tests, прямых access rules и внутреннего
superuser-only CAS endpoint. Task 05 определяет названия и поля схемы, Task 09
реализует и проверяет её на временной базе, Task 10 адаптирует hook. Новая схема
включает `users`, `subjects`, `groups`, `assignments`, `teaching_reports`,
`teaching_report_entries`, `substitutions`; это не разрешает клиенту обращаться
к ним.

Текущий hook `data/pocketbase/pb_hooks/report_storage.pb.js` уже демонстрирует
транзакцию и compare-and-swap. Его следует сохранить как узкий storage primitive,
но убрать из него дублирование status/period/teacher в дочерних строках и не
добавлять туда проверки роли, формы или HTTP-сессии.

## Фактическая карта исходной версии

Эта карта нужна для безопасной замены, а не как целевая структура.

| Сценарий | Экран → состояние → API | Маршрут → service → storage | Наблюдение |
|---|---|---|---|
| вход | `LoginScreen` → `AuthCubit` → `AuthRepository` → `ApiService` | `/api/auth/users`, `/api/auth/login`, `/api/auth/me` в `server/lib/server.dart` → `PocketBaseStore` | токен живёт только в памяти; restore/logout требуется спроектировать заново |
| учитель | `TeacherHomeScreen` / `FillTeachingReportScreen` → `TeachingReportCubit` → `TeachingReportRepository` | `/api/teachers/...`, `/api/reports/...` → `ReportService` → `PocketBaseStore` | текущая политика периода и DTO не являются контрактом новой версии |
| завуч | `AdminHomeScreen` / `ReviewScreen` → `AdminCubit` → teacher repository | `/api/admin/months/...`, `/api/reports/...` → тот же `ReportService` | admin зависит от teacher feature; нужен общий слой |
| запись | editor/admin Cubit → `change` | `/api/reports/.../<action>` → `ReportService.change` → `writeReport` → internal hook | полезен CAS, но текущие поля и дублирование не переносятся автоматически |

Также подтверждено, что `server/lib/server.dart:createHandler` сейчас объединяет
routes, CORS, авторизацию, error mapping и static serving; `ReportService`
оперирует `RecordModel` через `PocketBaseStore`. `client/pubspec.yaml` уже не
содержит PocketBase SDK. Стек, который сохраняется: Flutter, Cubit/
`flutter_bloc`, Freezed, `go_router`, `get_it`, HTTP; Dart Shelf,
`shelf_router`, `shelf_static`, PocketBase SDK; PocketBase 0.40.1/SQLite.

## Порядок чистого переключения

Старая база и старый API не являются контрактом перехода. Рабочие данные не
удаляются неявно: любые действия со старой локальной базой будут отдельно
документированы и ограничены Task 25. До этого новая версия использует только
временный/явно заданный изолированный экземпляр.

1. **Нормативные решения (01–08).** Task 02 фиксирует точные часы; 03 и 04
   закрывают продуктовые решения; 05 объединяет их в schema; 06 публикует DTO;
   07 определяет доказательства; 08 — runtime. На этом этапе код старой версии
   не объявляется совместимым и не меняется «частями».
2. **Изолированная data-основа (09–10).** Task 09 создаёт чистую схему и
   изолированные тесты, затем Task 10 делает проверяемый CAS. Промежуточное
   состояние пригодно только для schema/storage tests, не для деплоя: Shelf и
   клиент ещё используют старые контракты.
3. **Новый серверный контракт (11–13).** Сначала HTTP/auth boundaries, затем
   queries и commands. Каждый этап имеет server/integration tests из Task 07;
   до готовности полного набора команд это не release-кандидат и не требует
   адаптера старого API.
4. **Новый клиент поверх закреплённого API (14–20).** Task 14 создаёт общие
   модели и API-слой только после schema/API/test strategy. 15–20 заменяют
   ролевые сценарии; feature работают против нового Shelf API. Частично
   переделанный client не деплоится, если нужный server route ещё не готов.
5. **Согласованный продукт (21–28).** UI QA и master check, E2E, очистка,
   runtime/deploy, CI и корневые документы выполняются только на едином
   снимке. Только Task 28 может объявить продукт готовым к приёмке.

Нет промежуточного состояния, в котором новый клиент обязан поддерживать
старый API либо старый Shelf — новую схему. Если разработка требует временно
держать два набора артефактов в дереве, каждый запускается лишь в изолированном
стенде своей задачи; compose/deploy не указывает его как готовое приложение.

## Владельцы следующих нормативных документов

| Артефакт | Владелец | Используют |
|---|---|---|
| `decimal_contract.md` | 02 | 05, 06, 12–14, 17–18 |
| `report_policy.md` | 03 | 05–06, 12–13, 16–20 |
| `session_contract.md` | 04 | 05–06, 08, 11, 15 |
| `data_schema.md` | 05 | 06, 09–13 |
| `api_contract.md`, `api_examples.json` | 06 | 07–08, 10–23 |
| `test_strategy.md` | 07 | 09, 14, 22–23, 28 |
| `runtime_contract.md` | 08 | 22, 24–27 |

Task 27 сводит фактическую итоговую архитектуру в root README и AGENTS; этот
документ остаётся историческим нормативным входом плана. Вопрос о сохранении
нативных Flutter-оболочек намеренно не решается сейчас: основная цель — Web, а
Task 24 сначала докажет их использование или неиспользование перед удалением.

## Проверяемые инварианты для последующих задач

- Новый browser client делает только HTTP-вызовы к Shelf; прямой PB запрос,
  SDK или collection name в `client/` — дефект.
- Ни один слой, кроме Shelf application service, не принимает окончательное
  решение о правах, валидности, итогах или переходе статуса.
- Каждый write полного отчёта использует revision и один атомарный storage
  primitive; при 409 или ошибке клиент сохраняет локальный ввод.
- PB получает только внутреннюю проверенную команду от сервера; обычный
  пользователь не получает прямого доступа к прикладным коллекциям.
- Каждый временный этап имеет назначенные Task 07 проверки и не называется
  deployable до прохождения релевантных последующих этапов.

## Проверка решения

Ручная трассировка выполнена 2026-09-17 по текущему коду: для входа, чтения
отчёта, save/submit и confirm/return прослежены экран, Cubit, repository/API,
route, `ReportService`, `PocketBaseStore` и hook. Она подтвердила границы,
которые требуется заменить, и отсутствие прямого PocketBase SDK в клиенте.
Проверка не заявляет работу будущих сценариев: их докажут задачи 11–23.
