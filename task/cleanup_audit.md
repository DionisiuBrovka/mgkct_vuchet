# Аудит очистки репозитория

Дата: 2026-09-18. Область: Task 24, только подтверждённо устаревшие исходники
и generated/local artefacts.

| Решение | Основание | Проверка |
| --- | --- | --- |
| Удалены legacy `TeachingReportRepository`, `ReportSnapshot`, `Assignment`, `Substitution`, `TeachingReportEntry` и их Freezed output | `rg` не нашёл рабочих импортов после перехода на `core/domain.dart` и `ReportRepository`; прежние модели хранили `double`, несовместимый с точным DTO | `flutter analyze`, `flutter test` |
| `StatusBadge` и `MonthStatusCard` используют `ReportStatus` | Это текущий enum API DTO; не требуется legacy model ради статуса | `flutter analyze` |
| Удалены `ReviewAssignmentCard`, `intl`, direct `json_annotation` и `json_serializable` | Виджет не импортировался, `intl` был его единственным потребителем; аннотация остаётся transitively нужна Freezed, но больше не является direct dependency | `flutter pub get`, `flutter analyze`, `flutter test` |
| Удалён неупоминаемый `back.jpg` | `pubspec.yaml` и код используют только `assets/images/back.png` | `flutter build web --release` |
| Удалены Android/iOS/Linux/macOS/Windows scaffolds | Runtime contract задаёт Web как единственную целевую платформу; команды и CI собирают Web | `flutter build web --release` |
| Удалён машинозависимый `.vscode/settings.json` | Содержал абсолютный путь к чужой FVM-installation | визуальная проверка содержимого пути |
| Сохранены `app_user.freezed.dart`, `pubspec.lock`, `back.png`, service-account ignore | AppUser всё ещё использует Freezed; lockfile нужен воспроизводимой сборке; PNG объявлен asset; ключ локален и не читается/не удаляется | `rg`, `git check-ignore`, `git ls-files` |

Проверка секретов без чтения их содержимого: `git ls-files` для service account,
PB data и build не вернул путей; `git log --all -- client/assets/service_account.json`
также не вернул коммитов. `.env`, service account, PB data, build и generated
native stubs исключены из Git и Docker build context.

Повторная генерация Freezed выполняется из `client/` командой
`dart run build_runner build --delete-conflicting-outputs`; generated output
хранится в Git только когда он реально импортируется. `pubspec.lock` хранится.
