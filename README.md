# 📚 Вычитка — Учёт учебной нагрузки преподавателей

Flutter-приложение для сбора и подтверждения данных о вычитанных часах преподавателей. Бэкенд — Google Таблицы (Google Sheets API v4).

---

## Содержание

- [О проекте](#о-проекте)
- [Роли и права доступа](#роли-и-права-доступа)
- [Стек технологий](#стек-технологий)
- [Структура Google Таблицы](#структура-google-таблицы)
- [Структура проекта](#структура-проекта)
- [Установка и настройка](#установка-и-настройка)
- [Архитектура приложения](#архитектура-приложения)
- [Экраны и пользовательский сценарий](#экраны-и-пользовательский-сценарий)
- [Модели данных](#модели-данных)
- [Сервисный слой](#сервисный-слой)
- [Ограничения и квоты Google Sheets API](#ограничения-и-квоты-google-sheets-api)
- [Безопасность](#безопасность)
- [Возможные доработки](#возможные-доработки)

---

## О проекте

**Вычитка** — это ежемесячный отчёт преподавателя о количестве вычитанных часов по каждому виду учебной нагрузки (лекции, лабораторные/практические, курсовые проекты, консультации, дополнительный контроль, экзамены).

Приложение решает следующие задачи:

- Преподаватель выбирает своё ФИО и вводит пароль
- Заполняет часы по каждому назначению (предмет + группа) за текущий месяц
- Отправляет вычитку на проверку
- Завуч/администратор просматривает все поданные вычитки и подтверждает их
- После подтверждения вычитка **блокируется и не может быть изменена**
- Все данные хранятся в Google Таблице, доступной администратору напрямую

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
| Бэкенд | Google Sheets API v4 |
| Авторизация в API | Service Account (JSON-ключ) |
| HTTP / Google API | `googleapis` + `googleapis_auth` |
| Модели | `freezed` + `json_serializable` |
| DI | `get_it` |
| Навигация | `go_router` |

**`pubspec.yaml` зависимости:**

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Google API
  googleapis: ^13.0.0
  googleapis_auth: ^1.6.0
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

## Структура Google Таблицы

Таблица содержит **4 листа**. Администратор создаёт таблицу вручную и заполняет первые два листа перед запуском приложения.

---

### Лист 1 — `Пользователи`

Заполняется администратором вручную. Содержит всех пользователей системы.

| Столбец | Название | Описание |
|---|---|---|
| A | name | Полное ФИО (именно так будет отображаться в приложении) |
| B | password | Пароль в открытом виде |
| C | role | `teacher` или `admin` |

**Пример:**

| name | password | role |
|---|---|---|
| Иванов Иван Иванович | pass123 | teacher |
| Петрова Анна Сергеевна | qwerty | teacher |
| Сидоров Алексей Петрович | admin2024 | admin |

---

### Лист 2 — `Назначения`

Заполняется администратором. Определяет, какой преподаватель ведёт какой предмет в какой группе.

| Столбец | Название | Описание |
|---|---|---|
| A | teacher | ФИО преподавателя (точно как в листе Пользователи) |
| B | subject | Название учебного предмета |
| C | course | Курс (1, 2, 3 и т.д.) |
| D | group | Номер учебной группы |

**Пример:**

| teacher | subject | course | group |
|---|---|---|---|
| Иванов Иван Иванович | Математика | 1 | 101 |
| Иванов Иван Иванович | Математика | 1 | 102 |
| Иванов Иван Иванович | Алгебра | 2 | 201 |
| Петрова Анна Сергеевна | Физика | 1 | 101 |

---

### Лист 3 — `Вычитки`

Заполняется приложением автоматически. Каждая строка — одна запись (преподаватель × предмет × группа × месяц).

| Столбец | Название | Описание |
|---|---|---|
| A | id | Уникальный UUID записи |
| B | teacher | ФИО преподавателя |
| C | month | Месяц (например, `Октябрь`) |
| D | year | Год (например, `2025`) |
| E | subject | Учебный предмет |
| F | course | Курс |
| G | group | Учебная группа |
| H | лек | Лекции (часы) |
| I | лр_пр | Лабораторные / практические (часы) |
| J | кп | Курсовой проект (часы) |
| K | конс | Консультации (часы) |
| L | доп_контр | Дополнительный контроль (часы) |
| M | экз | Экзамен / дифференцированный зачёт (часы) |
| N | status | `draft` / `submitted` / `confirmed` |
| O | submitted_at | Дата и время отправки (ISO 8601) |
| P | confirmed_at | Дата и время подтверждения (ISO 8601) |
| Q | confirmed_by | ФИО завуча, который подтвердил |

---

### Лист 4 — `Замены`

Заполняется приложением. Каждая строка — одна замена преподавателя.

| Столбец | Название | Описание |
|---|---|---|
| A | teacher | ФИО преподавателя |
| B | month | Месяц |
| C | year | Год |
| D | group | Группа, которую заменял |
| E | date | Дата замены (`ДД.ММ.ГГГГ`) |
| F | hours | Количество часов |

---

## Структура проекта

```
vychitka_app/
├── android/
├── ios/
├── assets/
│   └── service_account.json      # ← ключ сервисного аккаунта (в .gitignore!)
├── lib/
│   ├── main.dart
│   ├── app.dart                  # MaterialApp + GoRouter
│   ├── injection.dart            # get_it регистрация зависимостей
│   │
│   ├── core/
│   │   ├── constants.dart        # ID таблицы, названия листов, месяцы
│   │   ├── sheets_service.dart   # весь CRUD с Google Sheets API
│   │   └── extensions.dart       # вспомогательные расширения
│   │
│   ├── features/
│   │   │
│   │   ├── auth/
│   │   │   ├── models/
│   │   │   │   └── app_user.dart
│   │   │   ├── repository/
│   │   │   │   └── auth_repository.dart
│   │   │   ├── cubit/
│   │   │   │   ├── auth_cubit.dart
│   │   │   │   └── auth_state.dart
│   │   │   └── screens/
│   │   │       └── login_screen.dart
│   │   │
│   │   ├── teacher/
│   │   │   ├── models/
│   │   │   │   ├── assignment.dart        # назначение преподавателя
│   │   │   │   ├── vychitka_entry.dart    # строка вычитки
│   │   │   │   └── zamena.dart            # замена
│   │   │   ├── repository/
│   │   │   │   └── vychitka_repository.dart
│   │   │   ├── cubit/
│   │   │   │   ├── vychitka_cubit.dart
│   │   │   │   └── vychitka_state.dart
│   │   │   └── screens/
│   │   │       ├── teacher_home_screen.dart    # список месяцев со статусами
│   │   │       ├── fill_vychitka_screen.dart   # форма заполнения
│   │   │       └── confirm_screen.dart          # итоги перед отправкой
│   │   │
│   │   └── admin/
│   │       ├── cubit/
│   │       │   ├── admin_cubit.dart
│   │       │   └── admin_state.dart
│   │       └── screens/
│   │           ├── admin_home_screen.dart   # все вычитки всех препод.
│   │           └── review_screen.dart       # просмотр + подтверждение
│   │
│   └── shared/
│       ├── widgets/
│       │   ├── month_status_card.dart
│       │   ├── hours_input_field.dart
│       │   └── status_badge.dart
│       └── theme/
│           └── app_theme.dart
│
├── test/
├── pubspec.yaml
├── .gitignore
└── README.md
```

---

## Установка и настройка

### Шаг 1 — Google Cloud Console

1. Перейди на [console.cloud.google.com](https://console.cloud.google.com)
2. Создай новый проект (например, `vychitka-app`)
3. Включи API: **APIs & Services → Enable APIs → Google Sheets API**
4. Создай сервисный аккаунт: **IAM & Admin → Service Accounts → Create**
   - Название: `vychitka-service`
   - Роль: `Editor` (или `Viewer` — но тогда не сможет писать)
5. Создай JSON-ключ: **Keys → Add Key → Create new key → JSON**
6. Скачай файл и переименуй в `service_account.json`

### Шаг 2 — Настройка Google Таблицы

1. Создай новую Google Таблицу
2. Создай 4 листа с точными названиями:
   - `Пользователи`
   - `Назначения`
   - `Вычитки`
   - `Замены`
3. В каждом листе сделай строку заголовков (строка 1) согласно структуре выше
4. Заполни `Пользователи` и `Назначения`
5. **Дай доступ сервисному аккаунту:** Поделиться → вставь email из JSON-ключа (поле `client_email`) → роль **Редактор**
6. Скопируй ID таблицы из URL:
   ```
   https://docs.google.com/spreadsheets/d/ЭТОТ_ID_НУЖЕН/edit
   ```

### Шаг 3 — Настройка проекта Flutter

1. Клонируй репозиторий:
   ```bash
   git clone https://github.com/your-org/vychitka-app.git
   cd vychitka-app
   ```

2. Положи `service_account.json` в папку `assets/`:
   ```
   assets/
   └── service_account.json
   ```

3. Убедись что файл прописан в `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/service_account.json
   ```

4. Пропиши ID таблицы в `lib/core/constants.dart`:
   ```dart
   static const spreadsheetId = 'ВАШ_SPREADSHEET_ID_ЗДЕСЬ';
   ```

5. Установи зависимости:
   ```bash
   flutter pub get
   ```

6. Сгенерируй код моделей:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

7. Запусти приложение:
   ```bash
   flutter run
   ```

---

## Архитектура приложения

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                      │
│  LoginScreen │ TeacherHomeScreen │ AdminHomeScreen   │
│  FillVychitkaScreen │ ConfirmScreen │ ReviewScreen   │
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
│                   SheetsService                      │
│         (единственная точка работы с API)            │
└──────────────────────┬──────────────────────────────┘
                       │ googleapis
┌──────────────────────▼──────────────────────────────┐
│              Google Sheets API v4                    │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│               Google Таблица                         │
│  Пользователи │ Назначения │ Вычитки │ Замены        │
└─────────────────────────────────────────────────────┘
```

---

## Экраны и пользовательский сценарий

### Преподаватель

```
[Экран входа]
  • Выпадающий список ФИО всех преподавателей
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
        ▼ (нажать на месяц со статусом "черновик")
[Экран заполнения вычитки]
  • Заголовок: месяц + год
  • Для каждого назначения (предмет + курс + группа):
      ┌──────────────────────────────────────────┐
      │ Математика · 1 курс · гр. 101            │
      │  Лек:     [___]    ЛР/ПР:  [___]        │
      │  КП:      [___]    Конс:   [___]        │
      │  Доп.к:   [___]    Экз:    [___]        │
      └──────────────────────────────────────────┘
  • Секция "Замены":
      [+ Добавить замену]  →  группа / дата / часы
  • Кнопки:
      [Сохранить черновик]    [Отправить на проверку →]
        │
        ▼ (нажать "Отправить на проверку")
[Экран подтверждения]
  • Итоговая таблица: все назначения и часы
  • Итого часов по видам нагрузки
  • Список замен
  • Кнопки:
      [← Назад]    [✅ Подтвердить и отправить]
```

### Завуч / Администратор

```
[Экран входа]
  • Те же поля, что у преподавателя
        │
        ▼
[Главный экран администратора]
  • Фильтр по месяцу/году
  • Список всех преподавателей + статус за выбранный месяц:
      Иванов И.И.      📤 На проверке
      Петрова А.С.     ✅ Подтверждена
      Козлов В.Н.      ✏️  Черновик
        │
        ▼ (нажать на преподавателя со статусом "на проверке")
[Экран проверки вычитки]
  • Все данные вычитки (только просмотр)
  • Итоговые суммы по видам нагрузки
  • Список замен
  • Кнопки:
      [↩ Вернуть на доработку]    [✅ Подтвердить]
```

---

## Модели данных

### `AppUser`
```dart
@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String name,
    required String password,
    required UserRole role,
  }) = _AppUser;
}

enum UserRole { teacher, admin }
```

### `Assignment`
```dart
@freezed
class Assignment with _$Assignment {
  const factory Assignment({
    required String teacher,
    required String subject,
    required String course,
    required String group,
  }) = _Assignment;
}
```

### `VychitkaEntry`
```dart
@freezed
class VychitkaEntry with _$VychitkaEntry {
  const factory VychitkaEntry({
    required String id,
    required String teacher,
    required String month,
    required int year,
    required String subject,
    required String course,
    required String group,

    // Виды нагрузки
    @Default(0) double lek,        // Лекции
    @Default(0) double lrPr,       // ЛР / ПР
    @Default(0) double kp,         // Курсовой проект
    @Default(0) double cons,       // Консультации
    @Default(0) double dopKontr,   // Доп. контроль
    @Default(0) double ekz,        // Экзамен / диф. зачёт

    @Default(VychitkaStatus.draft) VychitkaStatus status,
    DateTime? submittedAt,
    DateTime? confirmedAt,
    String? confirmedBy,
  }) = _VychitkaEntry;

  // Сумма всех часов по записи
  double get totalHours => lek + lrPr + kp + cons + dopKontr + ekz;
}

enum VychitkaStatus { draft, submitted, confirmed }
```

### `Zamena`
```dart
@freezed
class Zamena with _$Zamena {
  const factory Zamena({
    required String teacher,
    required String month,
    required int year,
    required String group,
    required String date,    // ДД.ММ.ГГГГ
    required double hours,
  }) = _Zamena;
}
```

---

## Сервисный слой

`SheetsService` — единственный класс, работающий с Google Sheets API. Реализован как singleton.

### Публичное API сервиса

```dart
class SheetsService {
  // Инициализация (вызвать один раз при старте в main.dart)
  Future<void> init();

  // Пользователи
  Future<List<AppUser>> getUsers();

  // Назначения
  Future<List<Assignment>> getAssignments(String teacherName);

  // Вычитки — чтение
  Future<List<VychitkaEntry>> getVychitki({
    String? teacher,
    String? month,
    int? year,
  });

  // Вычитки — запись черновика
  Future<void> saveEntries(List<VychitkaEntry> entries);

  // Вычитки — обновить существующую запись
  Future<void> updateEntry(VychitkaEntry entry);

  // Преподаватель отправляет на проверку (draft → submitted)
  Future<void> submitMonth(String teacher, String month, int year);

  // Завуч подтверждает (submitted → confirmed)
  Future<void> confirmMonth(
      String teacher, String month, int year, String confirmedBy);

  // Завуч возвращает на доработку (submitted → draft)
  Future<void> rejectMonth(String teacher, String month, int year);

  // Замены
  Future<List<Zamena>> getZameny(String teacher, String month, int year);
  Future<void> saveZamena(Zamena zamena);
  Future<void> deleteZamena(String teacher, String month, int year, String date);
}
```

---

## Ограничения и квоты Google Sheets API

| Параметр | Лимит |
|---|---|
| Запросов в минуту | 300 (на проект) |
| Запросов в минуту на пользователя | 60 |
| Строк в таблице | ~10 млн |
| Размер ответа | 10 MB |

**Рекомендации для оптимизации:**

- Загружать весь лист одним запросом, фильтровать на стороне Dart — не делать отдельный запрос на каждую строку
- Кэшировать список назначений на сессию (они не меняются во время работы)
- Показывать `CircularProgressIndicator` при каждом обращении к API — задержка 500–2000 мс это норма

---

## Безопасность

> ⚠️ **Важно:** `service_account.json` содержит приватный ключ. Обращайся с ним как с паролем от банка.

### Обязательно:

- [ ] Добавить `assets/service_account.json` в `.gitignore`
- [ ] Никогда не коммитить файл ключа в репозиторий
- [ ] Для продакшна рассмотреть хранение ключа через `flutter_secure_storage` или серверный прокси

### `.gitignore` (минимум):
```gitignore
# Ключ сервисного аккаунта — НИКОГДА не коммитить!
assets/service_account.json

# Flutter
.dart_tool/
.packages
build/
*.g.dart
*.freezed.dart
```

### Ограничения текущей системы авторизации:

Пароли хранятся в открытом виде в Google Таблице. Это приемлемо для небольшой доверенной команды, но не подходит для публичного использования. Для повышения безопасности можно перейти на хранение хэшей паролей (SHA-256).

---

## Возможные доработки

| Фича | Сложность | Описание |
|---|---|---|
| Хэширование паролей | Низкая | Хранить SHA-256 вместо открытого текста |
| Push-уведомления | Высокая | Firebase Cloud Messaging — уведомить завуча о новой вычитке |
| Экспорт в PDF | Средняя | Генерация бланка вычитки для печати |
| История изменений | Средняя | Отдельный лист `Лог` со всеми правками |
| Офлайн-режим | Высокая | SQLite кэш + синхронизация при появлении сети |
| Веб-версия | Низкая | Flutter Web — тот же код, другая платформа |
| Telegram-бот для завуча | Средняя | Уведомления о новых вычитках в Telegram |
| Запланированные часы | Средняя | Сравнение вычитанного с запланированным |

---

## Учебный год и навигация по месяцам

Учебный год в колледже идёт с **сентября** по **август**. Порядок месяцев в приложении:

```dart
static const months = [
  'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',  // осень-зима
  'Январь', 'Февраль', 'Март', 'Апрель',          // весна
  'Май', 'Июнь', 'Июль', 'Август',                // лето
];
```

При отображении текущий месяц определяется автоматически через `DateTime.now()`.

---

## Лицензия

Внутренний проект УО «Минский государственный колледж цифровых технологий». Все права защищены.