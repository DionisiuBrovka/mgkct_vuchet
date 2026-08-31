# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Вычитка** — Flutter app for tracking monthly teaching workload hours at a college. Teachers log hours per subject/group assignment, submit for review, and admins confirm. Backend is **PocketBase** (self-hosted, REST API + SQLite, also serves the Flutter Web build). The README.md is the authoritative specification.

## Commands

```bash
# Start local PocketBase (applies migrations, serves on 127.0.0.1:8090)
bash tools/pocketbase/run.sh

# Install dependencies
flutter pub get

# Generate freezed/json_serializable models (run after any model changes)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Run tests
flutter test

# Check data-preserving migrations and rollback (temporary databases only)
python3 -m unittest discover -s tools/pocketbase/tests -v

# Run a single test file
flutter test test/path/to/test_file.dart

# Lint
flutter analyze
```

## Backend

- PocketBase schema is defined by migrations in `tools/pocketbase/pb_migrations/`. Never edit an applied migration — add a new file instead.
- `--automigrate=false` is required (both `tools/pocketbase/run.sh` and `docker/entrypoint.sh` set it). Without it PocketBase rewrites the schema and breaks collections.
- Docker deployment: see `docker/` and `DEPLOY.md`.
- Local PocketBase admin UI: `http://127.0.0.1:8090/_/`.

## Architecture

**Layer stack:** Screens → BLoC/Cubit → Repository → `PocketBaseService` → PocketBase API

`PocketBaseService` (`lib/core/pocket_base_service.dart`) is a singleton and the **only** class that talks to PocketBase. It encapsulates relation normalization (profile ↔ display_name, entry ↔ assignment). Repositories call it; cubits never call it directly.

DI is via `get_it`, registered in `lib/injection.dart`. Navigation is via `go_router` configured in `lib/app.dart`.

**Feature layout** (`lib/features/`):
- `auth/` — login screen, `AuthCubit`, `AuthRepository`, `AppUser` model
- `teacher/` — teacher home, teaching report form; `TeachingReportCubit`, `TeachingReportRepository`; models: `Assignment`, `TeachingReportEntry`, `Substitution`
- `admin/` — admin home, review screen; `AdminCubit`

Shared widgets live in `lib/shared/widgets/`.

**PocketBase collections**:
- `users` — auth accounts (email/password); extended with `display_name`
- `user_profiles` — links account → role (`teacher`/`admin`) + display_name + email
- `assignments` — teacher→subject→group→year mappings (`teacher` is a relation to profile)
- `teaching_report_entries` — workload entries written by the app; `assignment` is a relation; status: `draft` / `submitted` / `confirmed`
- `substitutions` — substitution records written by the app

## Key Constraints

- `PocketBaseService` is the only layer that knows about PocketBase relations (profile IDs, assignment IDs). Domain models stay flat.
- Fetch collections with filters, not per-row requests. Prefer `getFullList` with a PocketBase filter over repeated `getFullList` calls (see performance notes below).
- A `confirmed` entry is permanently locked — the app must never allow edits after confirmation.
- Academic year runs September–July (11 months). Month ordering in the UI follows `constants.dart`.
- `pocketBaseUrl` is configured in `lib/core/constants.dart` (and must point to a real server IP for production, see DEPLOY.md).

## Known pitfalls / refactoring notes

- `display_name` exists on **both** `users` and `user_profiles` (legacy duplicate). Prefer reading from `user_profiles`.
- `TeachingReportCubit.loadAllMonthStatuses` used to make one network request per month; prefer a single fetch and aggregate in Dart.
- Teacher home screen used to instantiate a throwaway `TeachingReportCubit`; use `TeachingReportRepository` directly instead.

## Models

All models use `freezed`. Key enums: `UserRole { teacher, admin }`, `TeachingReportStatus { draft, submitted, confirmed }`. `TeachingReportEntry` has six hour fields (lectureHours, practicalHours, courseProjectHours, consultationHours, additionalAssessmentHours, examHours) plus status/audit fields.

## Naming

Use the English names defined in README.md throughout code, API fields and configuration.
Dart fields use lowerCamelCase; PocketBase field names use snake_case and are mapped in
`PocketBaseService`. Legacy identifiers are allowed only in the README mapping table,
historical/transition migrations and migration test fixtures. Do not rename or reset
the database directory or deployment volumes when changing package or image names.
