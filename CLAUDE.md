# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Вычитка** — Flutter app for tracking monthly teaching workload hours at a college. Teachers log hours per subject/group assignment, submit for review, and admins confirm. Backend is Google Sheets API v4 (no server). The README.md is the authoritative specification.

**Current state:** Early scaffold — only `lib/main.dart` (Hello World) exists. All planned dependencies and features are yet to be implemented.

## Commands

```bash
# Install dependencies
flutter pub get

# Generate freezed/json_serializable models (run after any model changes)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Lint
flutter analyze
```

## Planned Dependencies

When implementing, add to `pubspec.yaml` per the spec:

```yaml
dependencies:
  googleapis: ^13.0.0
  googleapis_auth: ^1.6.0
  http: ^1.2.0
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0
  get_it: ^8.0.0
  go_router: ^14.0.0
  intl: ^0.19.0
  uuid: ^4.4.0

dev_dependencies:
  build_runner: ^2.4.9
  freezed: ^2.5.2
  json_serializable: ^6.8.0
```

## Architecture

**Layer stack:** Screens → BLoC/Cubit → Repository → `SheetsService` → Google Sheets API

`SheetsService` (`lib/core/sheets_service.dart`) is a singleton and the **only** class that talks to Google Sheets. Repositories call it; cubits never call it directly.

DI is via `get_it`, registered in `lib/injection.dart`. Navigation is via `go_router` configured in `lib/app.dart`.

**Feature layout** (`lib/features/`):
- `auth/` — login screen, `AuthCubit`, `AuthRepository`, `AppUser` model
- `teacher/` — teacher home, fill-vychitka form, confirm screen; `VychitkaCubit`, `VychitkaRepository`; models: `Assignment`, `VychitkaEntry`, `Zamena`
- `admin/` — admin home, review screen; `AdminCubit`

Shared widgets live in `lib/shared/widgets/`.

**Google Sheets structure** (4 sheets):
- `Пользователи` — users (name, password, role); admin-populated
- `Назначения` — teacher→subject→course→group mappings; admin-populated
- `Вычитки` — workload entries written by the app; status: `draft` / `submitted` / `confirmed`
- `Замены` — substitution records written by the app

## Key Constraints

- `assets/service_account.json` (Google service account key) must **never** be committed — it's in `.gitignore`. The app reads it as a Flutter asset.
- Passwords are stored in plaintext in the Sheets `Пользователи` tab — acceptable for this trusted internal use case.
- Fetch entire sheets in one API call, then filter in Dart. Do not make per-row requests.
- A `confirmed` entry is permanently locked — the app must never allow edits after confirmation.
- Academic year runs September–August. Month ordering in the UI follows `constants.dart`.
- `spreadsheetId` is configured in `lib/core/constants.dart`.

## Models

All models use `freezed` + `json_serializable`. Key enums: `UserRole { teacher, admin }`, `VychitkaStatus { draft, submitted, confirmed }`. `VychitkaEntry` has six hour fields (lek, lrPr, kp, cons, dopKontr, ekz) plus status/audit fields.
