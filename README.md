# 📚 Вычитка — Учёт учебной нагрузки преподавателей

Flutter-приложение для сбора и подтверждения данных о вычитанных часах преподавателей. Бэкенд — **PocketBase** (самохостинг, одна Linux-машина в локальной сети колледжа).

---

## Содержание

- [О проекте](#о-проекте)
- [Роли и права доступа](#роли-и-права-доступа)
- [Стек технологий](#стек-технологий)
- [Структура данных (PocketBase)](#структура-данных-pocketbase)
- [Структура проекта](#структура-проекта)
- [Установка и настройка](#установка-и-настройка)
- [Развёртывание](#развёртывание)
- [Архитектура приложения](#архитектура-приложения)
- [Экраны и пользовательский сценарий](#экраны-и-пользовательский-сценарий)
- [Модели данных](#модели-данных)
- [Сервисный слой](#сервисный-слой)
- [Учебный год и навигация по месяцам](#учебный-год-и-навигация-по-месяцам)
- [Безопасность](#безопасность)
- [Возможные доработки](#возможные-доработки)
- [Лицензия](#лицензия)

---

## О проекте

**Вычитка** — это ежемесячный отчёт преподавателя о количестве вычитанных часов по каждому виду учебной нагрузки (лекции, лабораторные/практические, курсовые проекты, консультации, дополнительный контроль, экзамены).

Приложение решает следующие задачи:

- Преподаватель выбирает своё ФИО и вводит пароль
- Заполняет часы по каждому назначению (предмет + группа) за текущий месяц
- Отправляет вычитку на проверку
- Завуч/администратор просматривает все поданные вычитки и подтверждает их
- После подтверждения вычитка **блокируется и не может быть изменена**
- Все данные хранятся в PocketBase (SQLite-база на сервере колледжа)

---

## Роли и права доступа

| Действие | Преподаватель | Завуч (Admin) |
|---|:---:|:---:|
| Войти по ФИО + пароль | ✅ | ✅ |
| Видеть свои назначения | ✅ | — |
| Заполнить вычитку (черновик) | ✅ | — |
| Отправить вычитку на проверку | ✅ | — |
| Редактировать черновик | ✅ | — |
| Видеть все вычитки всех преподавателей | — | ✅ |
| Подтвердить (заблокировать) вычитку | — | ✅ |
| Вернуть вычитку на доработку | — | ✅ |

**Статусная схема вычитки:**

```
[черновик] ──отправить──▶ [на проверке] ──подтвердить──▶ [подтверждена 🔒]
                                │
                          вернуть назад
                                │
                                ▼
                          [черновик]
```

---

## Стек технологий

| Слой | Технология |
|---|---|
| UI | Flutter 3.x |
| Управление состоянием | flutter_bloc / Cubit |
| Бэкенд | PocketBase (REST API + SQLite, отдаёт и веб-сборку) |
| HTTP / PocketBase | `pocketbase` |
| Модели | `freezed` |
| DI | `get_it` |
| Навигация | `go_router` |

**`pubspec.yaml` зависимости:**

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Backend
  pocketbase: ^0.25.0
  http: ^1.2.0

  # State management
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5

  # Models
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

  # DI & Navigation
  get_it: ^8.0.0
  go_router: ^14.0.0

  # Utils
  intl: ^0.19.0
  uuid: ^4.4.0

dev_dependencies:
  build_runner: ^2.4.9
  freezed: ^2.5.2
  json_serializable: ^6.8.0
```

---

## Структура данных (PocketBase)

Схема создаётся автоматически миграцией `tools/pocketbase/pb_migrations/1756000000000_init_collections.js`.

### Коллекция `users` (auth, встроенная)

Аккаунты для входа (это встроенная коллекция авторизации PocketBase). К базовым полям (`email`, `password`) добавлено поле `display_name` — то же ФИО, что и в профиле.

| Поле | Тип | Описание |
|---|---|---|
| id | text | ID записи |
| email | email | email (используется при authWithPassword) |
| password | password | пароль |
| display_name | text | ФИО преподавателя |

### Коллекция `user_profiles` (base)

Связывает аккаунт (users) с ролью и отображаемым именем. Именно по `display_name` приложение показывает пользователя и ищет его при входе.

| Поле | Тип | Описание |
|---|---|---|
| id | text | ID записи |
| user | relation → users | связанный аккаунт |
| display_name | text | ФИО (как в приложении) |
| email | email | email (для логина) |
| role | select | `teacher` / `admin` |

### Коллекция `assignments` (base)

Назначение «преподаватель → предмет → группа → учебный год».

| Поле | Тип | Описание |
|---|---|---|
| teacher | relation → user_profiles | преподаватель |
| subject | text | предмет |
| group | text | учебная группа |
| year | number | год начала учебного года |

### Коллекция `vychitki` (base)

Одна строка — запись «назначение × месяц × год» с часами и статусом.

| Поле | Тип | Описание |
|---|---|---|
| assignment | relation → assignments | назначение (предмет+группа) |
| month | text | месяц (например, `Октябрь`) |
| year | number | календарный год месяца |
| lek | number | лекции (часы) |
| lrPr | number | лаб./практические (часы) |
| kp | number | курсовой проект (часы) |
| cons | number | консультации (часы) |
| dopKontr | number | доп. контроль (часы) |
| ekz | number | экзамен / диф. зачёт (часы) |
| status | select | `draft` / `submitted` / `confirmed` |
| submitted_at | date | дата/время отправки |
| confirmed_at | date | дата/время подтверждения |
| confirmed_by | relation → user_profiles | завуч, подтвердивший вычитку |

### Коллекция `zameny` (base)

Замена преподавателя.

| Поле | Тип | Описание |
|---|---|---|
| teacher | relation → user_profiles | преподаватель |
| month | text | месяц |
| year | number | календарный год |
| group | text | группа, которую заменял |
| date | text | дата (ДД.ММ.ГГГГ) |
| hours | number | количество часов |

---

## Структура проекта

```
mgkct_vuchet/
├── android/ ios/ linux/ macos/ web/ windows/   # платформенные обёртки Flutter
├── assets/
│   └── images/back.png                          # фоновое изображение
├── docker/                                      # Docker-развёртывание
│   ├── Dockerfile                               # сборка Flutter Web + PocketBase
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│   └── build.sh
├── tools/pocketbase/                            # локальный PocketBase для разработки
│   ├── pocketbase                                # бинарник (в .gitignore)
│   ├── pb_migrations/                            # миграции схемы
│   └── run.sh                                    # локальный запуск
│
├── lib/
│   ├── main.dart                                 # точка входа
│   ├── app.dart                                  # MaterialApp + GoRouter
│   ├── injection.dart                            # get_it регистрация зависимостей
│   │
│   ├── core/
│   │   ├── constants.dart                        # URL, названия коллекций, месяцы
│   │   └── pocket_base_service.dart              # единственная точка работы с API
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── models/app_user.dart
│   │   │   ├── repository/auth_repository.dart
│   │   │   ├── cubit/{auth_cubit, auth_state}.dart
│   │   │   └── screens/login_screen.dart
│   │   ├── teacher/
│   │   │   ├── models/{assignment, vychitka_entry, zamena}.dart
│   │   │   ├── repository/vychitka_repository.dart
│   │   │   ├── cubit/{vychitka_cubit, vychitka_state}.dart
│   │   │   └── screens/{teacher_home, fill_vychitka}.dart
│   │   └── admin/
│   │       ├── cubit/{admin_cubit, admin_state}.dart
│   │       └── screens/{admin_home, review}.dart
│   │
│   └── shared/
│       ├── widgets/{month_status_card, hours_input_field, status_badge}.dart
│       └── theme/app_theme.dart
│
├── DEPLOY.md                                     # подробное развёртывание
├── CLAUDE.md
├── pubspec.yaml
└── README.md
```

---

## Установка и настройка

### Локальная разработка

1. Запусти локальный PocketBase:

   ```bash
   bash tools/pocketbase/run.sh
   # применяет миграции и поднимает API на http://127.0.0.1:8090
   ```

2. Установи зависимости:
   ```bash
   flutter pub get
   ```

3. Если менял модели (`freezed`) — сгенерируй код:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Запусти приложение:
   ```bash
   flutter run
   ```

> Если в базе нет пользователей, при первом старте контейнера (Docker) выполняется
> авто-засев тестовых данных (см. `docker/entrypoint.sh`). При локальном запуске
> пользователей/назначения добавляют через админку PocketBase (`http://127.0.0.1:8090/_/`).

### Конфигурация адреса

Адрес PocketBase задаётся в `lib/core/constants.dart`:

```dart
static const pocketBaseUrl = 'http://127.0.0.1:8090'; // разработка
// для прода — реальный IP сервера, например:
// static const pocketBaseUrl = 'http://192.168.1.50:8090';
```

---

## Развёртывание

Проект разворачивается **Docker-контейнером**: PocketBase (API + база) и собранная
Flutter Web-версия живут на одной Linux-машине и доступны по локальной сети.

```bash
bash docker/build.sh
```

Доступ:
- приложение — `http://<IP-сервера>:8090/`
- админка PocketBase — `http://<IP-сервера>:8090/_/`
- API-проверка — `curl http://<IP-сервера>:8090/api/health`

Полное руководство — в [DEPLOY.md](DEPLOY.md) (включая нативный способ без Docker, systemd-сервис, бэкапы, обновления).

---

## Архитектура приложения

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                      │
│  LoginScreen │ TeacherHomeScreen │ AdminHomeScreen   │
│  FillVychitkaScreen │ ReviewScreen                  │
└──────────────────────┬──────────────────────────────┘
                       │ BLoC / Cubit
┌──────────────────────▼──────────────────────────────┐
│                    Business Logic                    │
│  AuthCubit │ VychitkaCubit │ AdminCubit              │
└──────────────────────┬──────────────────────────────┘
                       │ Repository
┌──────────────────────▼──────────────────────────────┐
│                    Data Layer                        │
│  AuthRepository │ VychitkaRepository                 │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                   PocketBaseService                  │
│        (единственная точка работы с API)             │
└──────────────────────┬──────────────────────────────┘
                       │ pocketbase SDK
┌──────────────────────▼──────────────────────────────┐
│                    PocketBase                        │
│   users │ user_profiles │ assignments │ vychitki     │
│   zameny                                            │
└─────────────────────────────────────────────────────┘
```

**Ключевые решения:**

- `PocketBaseService` (`lib/core/pocket_base_service.dart`) — **единственный** класс, работающий
  с PocketBase. Репозитории вызывают его; кубиты никогда не обращаются к API напрямую.
- Маппинг relations (профиль ↔ имя, запись ↔ назначение) инкапсулирован в `PocketBaseService`.
- DI — через `get_it` (`lib/injection.dart`), навигация — через `go_router` (`lib/app.dart`).
- Запись со статусом `confirmed` **заблокирована**: сервис не даёт её обновить.

---

## Экраны и пользовательский сценарий

### Преподаватель

```
[Экран входа]
  • Выпадающий список ФИО всех пользователей
  • Поле пароля
  • Кнопка "Войти"
        │
        ▼
[Главный экран преподавателя]
  • Список месяцев текущего учебного года
  • У каждого месяца статус:
      ✏️  Черновик      — можно редактировать
      📤  На проверке   — ожидает завуча, нельзя редактировать
      ✅  Подтверждена  — заблокирована навсегда
  • Кнопка выхода
        │
        ▼ (нажать на месяц)
[Экран заполнения вычитки]
  • Заголовок: месяц + год
  • Для каждого назначения (предмет + курс + группа) — 6 полей часов
  • Секция "Замены": добавить/удалить (группа / дата / часы)
  • Кнопки: [Сохранить черновик] [Отправить →] (диалог подтверждения)
```

### Завуч / Администратор

```
[Экран входа]
  • Те же поля, что у преподавателя
        │
        ▼
[Главный экран администратора]
  • Выбор учебного года и месяца
  • Список всех пользователей + статус за выбранный месяц
        │
        ▼ (нажать на пользователя — статус "на проверке" или "подтверждена")
[Экран проверки вычитки]
  • Все данные вычитки (только просмотр)
  • Итоговые суммы по видам нагрузки
  • Список замен
  • Кнопки: [↩ Вернуть] [✓ Подтвердить]
```

> **Примечание по архитектуре:** отправка вычитки преподавателем происходит сразу из
> экрана заполнения через диалог подтверждения — отдельного промежуточного экрана нет.
> Экран проверки у завуча показывает итоговые таблицы и позволяет подтвердить/вернуть.

---

## Модели данных

### `AppUser`
```dart
enum UserRole { teacher, admin }

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,        // id аккаунта (users)
    required String profileId, // id профиля (user_profiles)
    required String name,      // display_name
    required UserRole role,
  }) = _AppUser;
}
```

### `Assignment`
```dart
@freezed
class Assignment with _$Assignment {
  const factory Assignment({
    required String teacher,
    required String subject,
    required String group,
    required int year,        // год начала учебного года
  }) = _Assignment;
}
```

### `VychitkaEntry`
```dart
enum VychitkaStatus { draft, submitted, confirmed }

@freezed
class VychitkaEntry with _$VychitkaEntry {
  const VychitkaEntry._();
  const factory VychitkaEntry({
    required String id,
    required String teacher,
    required String month,
    required int year,          // календарный год месяца
    required String subject,
    required String group,
    @Default('') String assignmentId,
    @Default(0) double lek,
    @Default(0) double lrPr,
    @Default(0) double kp,
    @Default(0) double cons,
    @Default(0) double dopKontr,
    @Default(0) double ekz,
    @Default(VychitkaStatus.draft) VychitkaStatus status,
    DateTime? submittedAt,
    DateTime? confirmedAt,
    String? confirmedBy,
  }) = _VychitkaEntry;

  double get totalHours => lek + lrPr + kp + cons + dopKontr + ekz;
}
```

### `Zamena`
```dart
@freezed
class Zamena with _$Zamena {
  const factory Zamena({
    @Default('') String id,
    required String teacher,
    required String month,
    required int year,
    required String group,
    required String date,      // ДД.ММ.ГГГГ
    required double hours,
  }) = _Zamena;
}
```

---

## Сервисный слой

`PocketBaseService` — единственный класс, работающий с PocketBase. Реализован как singleton
(регистрируется в `get_it`).

```dart
class PocketBaseService {
  PocketBaseService(this.baseUrl);

  Future<void> init();

  void logout();

  // Пользователи
  Future<AppUser?> login(String name, String password);
  Future<List<AppUser>> getAllUsers();

  // Назначения
  Future<List<Assignment>> getAssignments(String teacherName, int academicYear);

  // Вычитки — чтение
  Future<List<VychitkaEntry>> getVychitki({
    String? teacher,
    String? month,
    int? year,
  });

  // Вычитки — запись
  Future<void> saveEntries(List<VychitkaEntry> entries);
  Future<void> submitMonth(String teacher, String month, int year);
  Future<void> confirmMonth(String teacher, String month, int year, String confirmedBy);
  Future<void> rejectMonth(String teacher, String month, int year);

  // Замены
  Future<List<Zamena>> getZameny(String teacher, String month, int year);
  Future<void> saveZamena(Zamena zamena);
  Future<void> deleteZamena(String teacher, String month, int year, String date);
}
```

---

## Учебный год и навигация по месяцам

Учебный год в колледже идёт с **сентября** по **июль** (11 месяцев). Порядок в приложении:

```dart
static const months = [
  'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',  // осень-зима
  'Январь', 'Февраль', 'Март', 'Апрель',          // весна
  'Май', 'Июнь', 'Июль',                          // лето
];
```

Месяцы осенне-зимнего семестра относятся к году начала учебного года (`Сентябрь..Декабрь`),
остальные — к следующему календарному году. Текущий месяц определяется автоматически через
`DateTime.now()`.

---

## Безопасность

Проект рассчитан на **внутреннюю локальную сеть** доверенного колледжа.

- Пароли хранятся в коллекции `users` (PocketBase хранит их в виде хэша при создании записи;
  обратной расшифровки в приложении нет).
- В `.gitignore` исключены: бинарник PocketBase, `pb_data/`, `service_account.json` (артефакт от
  прежней версии на Google Sheets) — **не коммитить эти файлы**.
- Рекомендуется:
  - открывать порт `8090` только внутри локальной сети;
  - ограничить доступ к каталогу `pb_data/`;
  - периодически бэкапить `pb_data/data.db` (см. DEPLOY.md).

При желании перейти на публичный доступ — заменить PocketBase на HTTPS-прокси и включить
строгие правила (rules) коллекций для доступа по ролям.

---

## Возможные доработки

| Фича | Сложность | Описание |
|---|---|---|
| Экран создания пользователей/назначений | Средняя | UI для admin вместо ручного засева |
| Экран «Ход заполнения» для завуча | Средняя | сравнение вычитанного с запланированным |
| Экспорт в PDF | Средняя | генерация бланка вычитки для печати |
| История изменений | Средняя | коллекция «Лог» со всеми правками |
| Push / Telegram-уведомления | Высокая | оповещение завуча о новых вычитках |
| Строгие правила доступов | Средняя | rules коллекций по ролям для публичного доступа |
| Офлайн-режим | Высокая | локальный кэш + синхронизация |

---

## Лицензия

Внутренний проект УО «Минский государственный колледж цифровых технологий». Все права защищены.
