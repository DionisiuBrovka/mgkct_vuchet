# Контракт сохраняемой серверной сессии

Статус: нормативное решение Task 04 от 2026-09-17. Основание среды — принятый
владельцем HTTP-режим в изолированной локальной сети, записанный в
[open_questions.md](open_questions.md). Этот контракт обязателен для Task 05,
06, 08, 09, 11 и 15. При конфликте приоритет имеет
[product_spec.md](product_spec.md), затем этот документ.

## Решение

Новая версия использует собственную серверную сессию, а не PocketBase JWT в
клиенте. После проверки выбранного пользователя и пароля Shelf создаёт
криптографически случайный opaque credential (не менее 256 бит), отдаёт его
только в HttpOnly-cookie и хранит в PocketBase только его SHA-256 hash. PB JWT,
сервисные токены, пароль пользователя и роль не уходят в браузер.

Выбранный transport соответствует фактическому запуску: Shelf раздаёт Flutter
Web с того же origin по HTTP внутри изолированной LAN. Cookie не требует
несуществующего TLS-прокси, но `Secure` в этом режиме должен быть **false**.
Это не делает HTTP конфиденциальным: сеть должна быть доверенной и изолированной;
публичный интернет, гостевая Wi-Fi-сеть и прокси без TLS не являются допустимой
средой. Если Task 08 добавит HTTPS как отдельный режим, он переключает `Secure`
в true и проверяет его отдельно, не меняя модель сессии.

## Данные и серверная проверка

Task 05 создаёт закрытую base collection `app_sessions`; обычный PB-пользователь
не имеет list/view/create/update/delete rules. Поля и индексы:

| Поле | Тип / правило | Назначение |
|---|---|---|
| `user` | обязательная relation → `users`, один | владелец сессии |
| `token_hash` | обязательный text, SHA-256 credential, unique indexed | lookup без хранения секретного credential |
| `auth_version` | обязательный integer | версия полномочий user на момент login |
| `created_at` | обязательная server datetime | аудит срока, не пользовательская история |
| `last_seen_at` | обязательная server datetime | idle expiry |
| `expires_at` | обязательная server datetime, indexed | абсолютное истечение |
| `revoked_at` | optional server datetime, indexed | явный logout/отзыв |

`users` получает обязательный server-managed `is_active: bool` (default true)
и `auth_version: int` (default 1). При блокировке, разблокировке, изменении роли,
смене пароля или удалении user его `auth_version` увеличивается; PB hook/закрытая
операция администратора обязана применить это и отозвать связанные sessions.
Так прежняя cookie не оживает после разблокировки, а новая роль не начинает
действовать в старой сессии. Точная реализация PB hook — Task 09, но Task 05
фиксирует поля и доступ, а Task 11 всегда проверяет их на request path.

На **каждом** защищённом request Shelf по hash cookie получает session и
свежую запись user. Он принимает actor только когда одновременно:

1. credential корректно декодируется и hash соответствует ровно одной session;
2. `revoked_at` пуст, `now < expires_at` и `now - last_seen_at < 12 часов`;
3. user существует, `is_active == true`, role — `teacher` или `admin`;
4. `session.auth_version == user.auth_version`.

Только затем server помещает новый request-local actor `{id, name, role}` в
context. Он не берётся из cookie, local storage или process-global переменной.
`last_seen_at` обновляется server time при принятом защищённом request. Одна
неудача хранилища — 502/504, не 401 и не logout пользователя.

Сроки сессии: **12 часов неактивности**, **30 суток абсолютного срока** от
login. Max-Age cookie выставляется на меньший оставшийся срок и обновляется при
активности. Это сохраняет вход после перезагрузки или перезапуска браузера в
пределах сроков, но не превращает credential в бессрочный. Cleanup удаляет
истёкшие/давно revoked operational records; он не является историей действий.

## HTTP и cookie

Cookie имеет имя `mgkct_session`, value — opaque credential в base64url/иной
безопасной cookie-кодировке. Shelf задаёт:

```text
Path=/api
HttpOnly
SameSite=Strict
Secure=false                 # только принятому HTTP LAN-режиму
Max-Age=<оставшийся срок>
```

Не задаётся Domain: это host-only cookie для конкретного публичного Shelf host.
`Path=/api` не является защитой авторизации, а лишь сужает отправку cookie.
Все ответы сессии используют `Cache-Control: no-store` и не логируют cookie,
пароль, PB JWT или token hash.

Приложение — same-origin: Flutter Web грузится с Shelf и вызывает относительный
`/api`. CORS не является механизмом авторизации; он выключен по умолчанию и
может разрешать только явно заданный публичный origin для поддержанного клиента.
Для всех state-changing API (`POST`, а в будущем PUT/PATCH/DELETE) Shelf требует
`Origin`, в точности совпадающий с configured public origin. Это вместе с
`SameSite=Strict`, JSON `Content-Type` и отсутствием кросс-origin credentials
защищает от CSRF в web-сценарии. Запрос без Origin не допускается для browser
write; исключения для health и статического контента отсутствуют, а login также
проверяет Origin. Task 08 фиксирует public origin; Task 11 реализует middleware
и тесты positive/negative origin.

## Последовательности

### Login

1. Client получает публичный directory только с ID и именем; пароль вводится
   локально и передаётся HTTPS/HTTP только на `POST /api/auth/login` same-origin.
2. Shelf проверяет Origin, rate-limit и пароль через изолированный PB client;
   сразу читает актуальные `is_active`, role и `auth_version` user.
3. Неактивный/удалённый/невалидный user получает одинаковый 401, без раскрытия
   причины. Успех создаёт одну `app_sessions` запись и `Set-Cookie`.
4. Response содержит только безопасный DTO current user (`id`, `name`, `role`),
   но не credential, PB token, email, `is_active` или auth_version.
5. Клиент переводит Cubit в authenticated лишь по успешному response и не
   сохраняет роль/credential в localStorage, SharedPreferences или URL.

### Restore и защищённый request

1. При старте `AuthCubit` сначала имеет explicit `restoring` state; router не
   показывает интерфейс роли до завершения `GET /api/auth/me`.
2. Browser автоматически приложит HttpOnly cookie к same-origin `/api/auth/me`.
   Shelf выполняет полную session + current-user validation выше и возвращает
   свежий DTO role/name.
3. 200 переводит router в актуальную роль. 401 очищает cookie (`Max-Age=0`) и
   переводит к login. Cookie с неправильной кодировкой/unknown hash так же
   безошибочно очищается и даёт 401.
4. Timeout/502/504 не выдают за неверный пароль и не очищают cookie: UI остаётся
   в restore-unavailable state с Retry/Login; уже введённые данные формы не
   теряются. Успешный protected request также может продлить cookie.

### Logout, revoke и изменения user

`POST /api/auth/logout` требует валидную session, ставит её `revoked_at` в
серверной транзакции и возвращает clear-cookie. Повторный logout (уже очищенная,
expired или revoked cookie) всё равно возвращает успешный idempotent clear-cookie
без раскрытия существования session. Клиент всегда немедленно переходит к login.

При блокировке, смене role, password reset или удалении user admin-side hook
увеличивает `auth_version` и revoke-ит all sessions этого user. Даже до cleanup
следующий request увидит inactive/version mismatch и вернёт 401; повторный login
заблокированному user также возвращает 401. После разблокировки old cookies
остаются invalid из-за auth_version, требуется новый login. При смене роли новый
login получает новую роль; старая сессия не продолжает работу с прежними или
новыми правами.

Перезапуск Shelf не затрагивает `app_sessions`: она в PocketBase, поэтому
валидная cookie продолжает работать. Перезапуск PocketBase/недоступность PB
даёт только временную server error; он не превращает активного пользователя в
вышедшего.

### Гонки и изоляция

Login/restore/logout в client имеют monotonically increasing operation epoch.
Logout увеличивает epoch до очистки локального auth state; поздний response
предыдущего restore/login игнорируется и не может снова открыть роль. Каждый
Shelf request создаёт свой actor после проверки: два пользователя и параллельные
запросы не делят mutable auth context. Revoke между проверкой и command
разрешается проверкой session непосредственно в request middleware; write всё
равно проходит role/status/CAS проверку service/storage, а не доверяет старому
UI.

## Матрица результатов

| Событие | Shelf | Client |
|---|---|---|
| успешный login | создать session, `Set-Cookie`, вернуть fresh user | authenticated; credential недоступен JS |
| browser reload/restart до expiry | `/auth/me` валидирует registry + user | restoring → нужная роль |
| idle > 12h / absolute > 30d | 401 + clear-cookie | login, без ложной network error |
| explicit logout / повторный logout | revoke если есть; всегда clear-cookie/200 | login; late response игнорируется |
| admin revoke или block | session invalid, 401; login запрещён, если inactive | следующий запрос → login |
| смена role | auth_version mismatch/revoke, 401 | следующий запрос → login; новый login получает новую роль |
| удаление user | 401; server не выдаёт старые данные | login |
| PB/Shelf unavailable | 502/504, cookie не считается invalid | restore unavailable/retry, не password error |
| Shelf restart | registry остаётся в PB | restore работает как до restart |

## Явные границы угроз

HttpOnly устраняет чтение credential обычным XSS-кодом, но не устраняет
возможность XSS выполнять same-origin запросы; поэтому необходимы CSP/escaping
и Origin check в Task 11/08. `Secure=false` означает, что сетевой перехват в
недоверенной сети может украсть cookie; это принимается только для обозначенной
изолированной LAN и должно быть видно в deploy docs. Не добавляются OAuth, SSO,
password recovery, multi-device UI, история сессий или «запомнить навсегда».

## Передача реализации

- **05:** `users.is_active`, `users.auth_version`, `app_sessions` fields,
  unique/index/access rules и cascade/delete policy.
- **06:** login/me/logout routes, public/credential-free DTO, 401/403/502/504,
  Set-Cookie/Origin semantics.
- **08:** same-origin HTTP LAN public origin, CORS/CSP, clock and optional
  future HTTPS switch.
- **09:** temporary PB schema + hook tests for user update/revoke and direct
  access ban.
- **11:** crypto RNG/hash, session store, request middleware, rate limit,
  cookie/Origin/error handling and integration tests.
- **14–15:** cookie-based API client, restore state, operation epoch, routing,
  logout and UI network-error tests.

## Проверка решения

Ручная трассировка 2026-09-17: текущие `PocketBaseStore.login/authenticate`
изолируют PB clients, но передают PB token как bearer; `ApiService._token` живёт
только в памяти, а server не имеет logout. Пройдены contract-сценарии login →
browser restart → block → request → relogin и logout → reuse old cookie;
матрица показывает соответственно restore/401/relogin и clear-cookie/401.
Решение не предполагает TLS-компонент: `docker-compose.yml` публикует Shelf
HTTP, PB остаётся localhost-only. Реализация, миграции и тесты намеренно
оставлены следующим задачам.
