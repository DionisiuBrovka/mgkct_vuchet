# HTTP API и DTO новой версии

Статус: нормативное решение Task 06 от 2026-09-17. Base path — `/api`; это
единственный API, старые routes/profileId/PB tokens не поддерживаются. Клиент
не знает PocketBase collections. Все JSON использует UTF-8, `Content-Type:
application/json`, `Cache-Control: no-store`.

## Общие правила

- Public только `GET /health`, `GET /auth/users`, `POST /auth/login`.
- Остальные routes требуют `mgkct_session` cookie из session contract. Shelf
  проверяет session, `is_active`, `auth_version` и актуальную role на каждом
  request; client role никогда не является доказательством права.
- State-changing requests требуют same-origin `Origin`; body до 1 048 576
  bytes. Cookie HttpOnly, `SameSite=Strict`, `Secure=false` только для принятой
  изолированной HTTP LAN-среды.
- Технические period values: `year` — calendar integer, `month` — integer
  1..12. Shelf разрешает только сентябрь–июль; август — 422.
- Часы и totals — только canonical decimal JSON strings из `decimal_contract`.
  JSON number, `null`, exponent и неканоническая строка — 422. Date замены —
  `YYYY-MM-DD`; timestamps — RFC 3339 UTC strings или `null`.
- Request objects строго типизированы: неизвестное поле, пропущенное required
  поле, неверный type или duplicate ID — 422. Response может расширяться
  только новым documented optional field; client игнорирует неизвестные поля.

## DTO

```text
User          { id: string, name: string, role: "teacher" | "admin" }
Period        { academicYear: int, year: int, month: int, status: Status }
Status        "draft" | "submitted" | "confirmed"
Confirmation  { at: RFC3339 string, by: User } | null
Hours         six canonical decimal strings (см. ниже)
```

`Report`:

```json
{
  "id": null,
  "teacher": {"id":"...","name":"...","role":"teacher"},
  "period": {"academicYear":2026,"year":2026,"month":9},
  "status":"draft", "revision":0, "confirmation":null,
  "entries":[{"id":null,"assignment":{"id":"...","subject":"...","group":"..."}, "lectureHours":"0", "practicalHours":"0", "courseProjectHours":"0", "consultationHours":"0", "additionalAssessmentHours":"0", "examHours":"0", "totalHours":"0"}],
  "substitutions":[{"id":null,"date":"2026-09-05","description":"...","hours":"1.25"}],
  "totals":{"lectureHours":"0","practicalHours":"0","courseProjectHours":"0","consultationHours":"0","additionalAssessmentHours":"0","examHours":"0","assignmentTotal":"0","substitutionTotal":"1.25","grandTotal":"1.25"}
}
```

`id:null`, `revision:0` — несохранённый draft, созданный server read из
актуальных assignments. `entry.totalHours` и all `totals` вычисляет Shelf,
они никогда не принимаются write body. Для persisted child ID — PB string;
`null` означает создать child. `ReportInput` содержит ровно `revision`,
`entries`, `substitutions`; entry input содержит `id`, `assignmentId` и шесть
hours; substitution input — `id`, `date`, `description`, `hours`.

## Routes

| Method/path | Role | Request | Success | Основные ошибки |
|---|---|---|---|---|
| GET `/health` | public | — | `{status:"ok"}` | 502, 504 |
| GET `/auth/users` | public | — | `{users:[{id,name}]}` | 502, 504 |
| POST `/auth/login` | public | `{userId,password}` | 200 `{user:User}`, Set-Cookie | 400, 401, 429, 502, 504 |
| GET `/auth/me` | session | — | `{user:User}` | 401, 502, 504 |
| POST `/auth/logout` | session/none | `{}` | 204 + clear-cookie; idempotent | 400 only malformed body |
| GET `/teacher/periods` | teacher | — | `{periods:[Period]}` for server current year | 401, 403, 502 |
| PUT `/teacher/reports/{year}/{month}` | teacher | ReportInput | Report draft | 401,403,409,422 |
| POST `/teacher/reports/{year}/{month}/submit` | teacher | ReportInput | Report submitted | 401,403,409,422 |
| GET `/reports/{teacherId}/{year}/{month}` | teacher/admin | — | Report | 401,403,404,409 |
| GET `/admin/periods` | admin | — | `{periods:[{academicYear,year,month}]}` | 401,403 |
| GET `/admin/reports?year=Y&month=M&q=T&status=S` | admin | optional q/status | `{teachers:[{id,name,status}]}` | 401,403,422 |
| POST `/admin/reports/{teacherId}/{year}/{month}/confirm` | admin | `{revision}` | Report confirmed | 401,403,409 |
| POST `/admin/reports/{teacherId}/{year}/{month}/return` | admin | `{revision}` | Report draft | 401,403,409 |

Teacher read requires own `teacherId` and a period in current server year.
Admin read permits only `submitted`/`confirmed`; draft is not openable by admin.
Admin period list includes current and persisted historical periods. Filtering is
server-side: `q` is optional trimmed name fragment (max 200), `status` optional
enum; both combine with AND before pagination is needed. This prevents client
from receiving a wider directory than the selected review scope.

Save/submit are complete aggregate commands. For first write `revision=0`; on
each successful save, submit, confirm or return revision grows by one. Server
checks exact assignment composition, ownership and expected revision atomically;
conflict has no merge and client rereads. Submit additionally requires
`grandTotal > "0"`; save permits zero. Confirm/return accept no entries,
substitutions, status or confirmation fields.

## Error envelope

Every API error is:

```json
{"error":{"code":"revision_conflict","message":"Отчёт уже изменён. Обновите данные.","fields":[]}}
```

`fields` is omitted unless field validation failed; then it is an array of
`{path,code,message}`, where path is JSON Pointer-like (`/entries/0/lectureHours`).
Messages are Russian and safe for UI; code is stable English snake_case.

| HTTP | code examples | Meaning |
|---|---|---|
| 400 | `malformed_json`, `invalid_content_type`, `invalid_origin` | transport cannot be parsed/accepted |
| 401 | `session_required`, `session_expired`, `session_revoked`, `invalid_credentials` | login/session failure; clear cookie for invalid session |
| 403 | `forbidden`, `teacher_period_unavailable` | valid actor lacks action/period right |
| 404 | `route_not_found`, `report_not_found` | unknown endpoint or allowed resource absent |
| 409 | `revision_conflict`, `status_conflict`, `assignment_set_changed` | reread; no automatic merge |
| 413 | `payload_too_large` | body exceeds 1 048 576 bytes; never truncate |
| 422 | `invalid_request`, `invalid_decimal`, `invalid_date`, `empty_report` | semantic input failure |
| 429 | `login_rate_limited` | retry later |
| 502 | `storage_unavailable` | PB failed; client preserves form/session |
| 504 | `storage_timeout` | PB timed out; client preserves form/session |

## Scenarios and consistency

Login never returns password, email, PB JWT or session credential. Browser
restart calls `/auth/me` before router role choice. A 401 resets client session;
502/504 produces restore-unavailable/retry, not false logout. Logout always
clears cookie even if no valid session remains. PB/Shelf restart does not change
valid persisted session semantics.

Report read obtains a single consistent aggregate: server reads report and
children, detects revision change, retries boundedly or returns 409. Responses
always return fresh exact totals. Teacher gets a server-built empty report when
no record exists; admin cannot create a report by reading. A report only with a
positive substitution is valid on submit; all-zero entries/substitutions yield
`empty_report` 422.

## Contract verification

`api_examples.json` contains all DTO shapes and required negative outcomes.
Task 07 converts its scenarios to tests; 11–13 implement routes; 14 consumes
the same models. No response exposes PB field/collection names or legacy
`profileId`.
