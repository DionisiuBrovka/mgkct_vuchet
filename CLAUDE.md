# Project guide

README.md describes only the current implemented project. Do not put task plans,
roadmaps, task lists or acceptance checklists in README.md.

## Layout

- `client/`: Flutter presentation, Cubits and HTTP client; no PocketBase SDK.
- `server/`: Dart Shelf API, authorization, validation and report workflow.
- `data/pocketbase/`: schema migrations, storage constraints and transactional CAS.
- Root `Dockerfile`, `pocketbase.Dockerfile`, `docker-compose.yml`, `build.sh` and
  `entrypoint.sh`: separate data and API/client images and startup.

Use English technical names. Domain terms are TeachingReport, TeachingReportEntry,
Substitution and Assignment. Russian UI labels and user data stay Russian.

Never edit an applied migration. New migrations must preserve data or fail explicitly
before committing inconsistent state. Do not automatically migrate a working database
when developing; use disposable databases or a read-only backup for verification.
Do not change persistent volume names or silently switch database directories.

Shelf owns all business rules. PocketBase's internal report-write endpoint is only a
transactional storage operation protected by superuser authentication. Never expose
service credentials to Flutter or share a mutable user auth context across requests.
Report changes require revision checks and save header, entries and substitutions
atomically. Confirmed reports are immutable through the application API.

## Checks

- `cd server && dart test && dart analyze`
- `cd client && flutter test && flutter analyze && flutter build web --release`
- `python3 -m unittest discover -s data/pocketbase/tests -v`

Tests must not touch working data. Shelf integration tests use localhost servers.
