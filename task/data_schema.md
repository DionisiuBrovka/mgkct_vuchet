# Чистая схема PocketBase

Статус: нормативное решение Task 05 от 2026-09-17. Схема создаётся только на
чистом PocketBase 0.40.1; она не мигрирует и не сохраняет старые records.
При конфликте приоритет: product spec, затем contracts 02–04, затем этот файл.

## Карта связей

```text
users ──< assignments >── subjects
  │              │
  │              └──────── groups
  ├──< teaching_reports ──< teaching_report_entries >── assignments
  │             └────────< substitutions
  └──< app_sessions
```

Все прикладные collections закрыты от обычных PB users. Только Shelf использует
сервисную учётную запись; закрытая PB admin-панель управляет users и
справочниками, но hooks не позволяют нарушить инварианты ниже.

## Collections и поля

### `users` (auth collection)

PocketBase штатно хранит `email`, password hash и системные поля. Единственное
отображаемое имя — штатное обязательное `name`; `display_name` и
`user_profiles` отсутствуют. Task 09 проверяет, что `name` именно штатное поле
PB 0.40.1 до создания миграции.

| Поле | Тип / ограничение |
|---|---|
| `name` | штатный Text, required, presentable; нормальный ввод имени в PB admin |
| `role` | Select, required, ровно одно: `teacher` или `admin` |
| `is_active` | Bool, required, default `true` |
| `auth_version` | Number, required integer, default `1`, min `1`; server-managed |

Изменение `is_active`, `role`, password или удаление user увеличивает
`auth_version` и revoke-ит его sessions по `session_contract.md`. Удаление user
запрещается, если существуют assignments, reports или sessions; сначала нужен
явный безопасный operational cleanup вне пользовательского продукта.

### `subjects` и `groups`

Обе base collections имеют одинаковый контракт.

| Поле | Тип / ограничение |
|---|---|
| `name` | Text, required, 1–200 Unicode code points; отображаемое русское название |
| `normalized_name` | Text, required, скрыт от API, unique index |

Нормализация: Unicode NFC; удалить края Unicode whitespace; внутренние
последовательности whitespace заменить одним ASCII space; выполнить Unicode
lowercase. `ё` и `е` различны. Пустой результат — ошибка. Hook вычисляет
`normalized_name` при create/update и не принимает подменённое значение,
поэтому index работает и при PB admin writes. Unique indexes:
`uq_subject_normalized_name(normalized_name)` и
`uq_group_normalized_name(normalized_name)`.

Переименование/удаление разрешено только пока record не используется
assignment. Используемый subject/group неизменяем: для исправления создаётся
новая запись. Task 09 реализует проверку входящих links в hook и тестирует
`" Математика "` / `"математика"` как дубликат, но `"е"` / `"ё"` как
разные допустимые имена.

### `assignments`

| Поле | Тип / ограничение |
|---|---|
| `teacher` | required one relation → `users`, `cascadeDelete=false`; только user role `teacher` |
| `subject` | required one relation → `subjects`, `cascadeDelete=false` |
| `group` | required one relation → `groups`, `cascadeDelete=false` |
| `academic_year` | required integer Number, `2000..2100`; год начала учебного года |
| `planned_main_hours` | optional Text, canonical nonnegative decimal string; пусто = план не задан |
| `planned_additional_hours` | optional Text, canonical nonnegative decimal string; пусто = план не задан |

Unique index `uq_assignment(teacher, subject, group, academic_year)` исключает
дубль четверки. Hook проверяет, что `teacher.role == teacher`. Когда assignment
уже связана хотя бы с одной `teaching_report_entries`, менять или удалять любое
поле идентичности (teacher, subject, group, academic_year) запрещено.
Плановые часы можно заполнять и исправлять в PB admin UI: это актуальный план,
а не часть сохранённого месячного отчёта. Новая миграция
`1791000000000_assignment_plans.js` добавляет поля без изменения старых данных
и применённой baseline-миграции.

### `teaching_reports`

| Поле | Тип / ограничение |
|---|---|
| `teacher` | required one relation → `users`, `cascadeDelete=false`, role teacher |
| `month` | required integer Number `1..12`; Shelf принимает только сентябрь–июль, август запрещён |
| `year` | required integer Number `2000..2100`, календарный год месяца |
| `status` | required Select: `draft`, `submitted`, `confirmed`; default `draft` |
| `revision` | required integer Number, min `1`; каждый сохранённый aggregate имеет revision ≥ 1 |
| `submitted_at` | optional server DateTime |
| `confirmed_at` | optional server DateTime |
| `confirmed_by` | optional one relation → `users`, `cascadeDelete=false`; role admin |

`uq_report_period(teacher, month, year)` гарантирует один aggregate на период.
Правила transition, согласованность подтверждающих полей и server period policy
принадлежат Shelf; hook принимает только уже проверенную command и CAS revision.
Record report не удаляется пользовательскими API и не cascade-delete-ит детей:
операторская попытка удаления при существующих children должна быть отказана.

### `teaching_report_entries`

| Поле | Тип / ограничение |
|---|---|
| `report` | required one relation → `teaching_reports`, `cascadeDelete=false` |
| `assignment` | required one relation → `assignments`, `cascadeDelete=false` |
| `lecture_hours` | required Text canonical decimal, default `"0"` |
| `practical_hours` | required Text canonical decimal, default `"0"` |
| `course_project_hours` | required Text canonical decimal, default `"0"` |
| `consultation_hours` | required Text canonical decimal, default `"0"` |
| `additional_assessment_hours` | required Text canonical decimal, default `"0"` |
| `exam_hours` | required Text canonical decimal, default `"0"` |

`uq_report_assignment(report, assignment)` исключает повтор строки. Каждое поле
часов имеет regex из `decimal_contract.md`:
`^(0|[1-9][0-9]*(\.[0-9]*[1-9])?)$`; max text length 1 048 576 bytes,
согласованный с max JSON body. Это не максимум часов, дробных разрядов или
округление. Здесь нет teacher/month/year/status/total/confirmation: всё выводимо
через report и assignment, а итог считает Shelf.

### `substitutions`

| Поле | Тип / ограничение |
|---|---|
| `report` | required one relation → `teaching_reports`, `cascadeDelete=false` |
| `date` | required Text, exact ISO `YYYY-MM-DD`; Shelf проверяет календарную дату и месяц report |
| `description` | required Text, trimmed, 1–500 Unicode code points |
| `hours` | required Text canonical decimal, default `"0"`, тот же regex/limit |

Каждая substitution имеет штатный PB ID. Нет relation на заменяемого teacher,
group, month/year/status/total или snapshot — требуется одно свободное
description и связь с report. Дата не DateTime: date-only исключает сдвиг дня
из-за часового пояса.

### `app_sessions`

Согласно Task 04: `user` relation (required, no cascade), `token_hash` required
Text (unique index), `auth_version` required integer, `created_at`,
`last_seen_at`, `expires_at` required server DateTime и optional `revoked_at`.
Indexes: `uq_session_token_hash(token_hash)`,
`idx_session_user(user)`, `idx_session_expiry(expires_at)`,
`idx_session_revoked(revoked_at)`. Credential хранится только как SHA-256 hash;
не создаётся из PB JWT и не возвращается API.

## Доступ и целостность

Для `users`, `subjects`, `groups`, `assignments`, `teaching_reports`,
`teaching_report_entries`, `substitutions`, `app_sessions` все PB
list/view/create/update/delete rules — `null` (только superuser), а manage
остаётся штатно закрытым. Исключение — встроенная password authentication,
которую Shelf использует с изолированным PB client для login; browser никогда
не вызывает PB. Public directory, roles, report access и session routes —
только Shelf API, не PB rules.

PB unique indexes и relation restrictions — защита данных. Shelf отвечает за
current actor, period, права и workflow. Hooks дополняют PB admin path:

- нормализуют subject/group и запрещают дубликаты;
- проверяют role teacher/admin на relations;
- запрещают изменение/удаление используемых references;
- инкрементируют `auth_version` и revoke-ят sessions при security-sensitive
  user change;
- разрешают write aggregate только внутреннему superuser endpoint.

## Договор атомарной записи отчёта

Shelf валидирует полную command и передаёт в superuser-only hook только:
teacher, calendar month/year, expected revision, target status/confirmation,
полный набор entry (assignment ID + six canonical strings) и substitution
(ID/new, date, description, canonical hours). Hook в одной PB transaction:

1. находит/создаёт report по unique period и сравнивает revision (для first
   create expected revision = 0);
2. проверяет ownership IDs children и уникальность assignment/child IDs;
3. создаёт/обновляет/удаляет children строго как состав command;
4. записывает report, увеличивает revision и либо commits всё, либо rollback.

Hook не принимает публичный HTTP, не вычисляет totals, не решает role/status
или validity формы. Shelf перед каждой command также сверяет свежий состав
assignments для draft по `report_policy.md`; изменение состава даёт 409/reread.

## Примеры приёмки

1. Создать active teacher `name` один раз, subject `Математика`, group `П-1`,
   assignment 2026. Повтор subject ` математика ` и повтор четверки не проходят
   unique constraint.
2. Создать report teacher/9/2026, одну entry с `"0.1"` и substitution
   `2026-09-05`, `"1000.125"`; точные strings хранятся без NumberField.
3. После создания entry попытка переименовать/удалить её assignment или её
   subject/group отклоняется; новая исправленная запись допустима.
4. Обычная учётная запись PB не может list/read/write любую collection; Shelf
   service account может выполнить только проверенную transaction.
5. При двух create для одного периода один commit выигрывает, второй получает
   revision/unique conflict без частичных children.

## Реализация и проверка

Task 09 создаёт одну новую baseline migration, а не цепочку legacy migrations,
и доказывает поля/index/rules/hooks на временном PB 0.40.1. Task 10 реализует
storage primitive; Task 11 — session fields/middleware; Task 12/13 — policy и
DTO. Рабочая база не удаляется неявно: Task 25 определит явный restricted
first-start/reset mode.
