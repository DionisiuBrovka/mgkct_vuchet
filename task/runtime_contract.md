# Runtime, сборка и LAN-развёртывание

Статус: нормативное решение Task 08 от 2026-09-17. Целевая платформа — Linux
x86_64 с Podman 5.8.4; Docker/Compose не поддерживается в этой версии, потому
что Docker отсутствует в проверенной среде. Task 25 реализует этот контракт.

## Зафиксированный runtime

| Компонент | Версия / источник | Проверка |
|---|---|---|
| Flutter | 3.44.8 stable | `flutter --version` |
| Dart | 3.12.2 | `dart --version` |
| PocketBase | 0.40.1 linux amd64 | `data/pocketbase/pocketbase --version` |
| PB binary SHA-256 | `bfdc715d14d922f3dfcb8333cc439e7eb1d44ed602456662299bf14f4d6387b8` | `sha256sum data/pocketbase/pocketbase` |
| OS image | Alpine 3.20 for PB; Debian bookworm-slim runtime | explicit version tag, resolved digest recorded by Task 25 build QA |
| builders | `ghcr.io/cirruslabs/flutter:3.44.0`, `dart:3.12.2-sdk` | exact published tag plus resolved image digest in final Dockerfiles |
| browser E2E | Node 24.18.0 + pinned Playwright | `node --version`, Task 23 lockfile |

Task 25 must fail preflight on non-x86_64 PB binary or SHA mismatch; it must
record real pulled image digests in deploy QA. Flutter build receives no secret
arguments or environment variables.

## Network, data и session

Podman network `mgkct_network` connects `app` and `pocketbase`. Only app
publishes `${APP_BIND:-0.0.0.0}:${APP_PORT:-8090}` to the LAN. PB binds only
`127.0.0.1:${PB_HOST_PORT:-8091}` on host for local administrator diagnostics;
ordinary LAN devices cannot reach it. Inside network app uses
`POCKETBASE_URL=http://pocketbase:8090`; this URL never reaches Flutter.

Shelf serves release Web and `/api` from one public origin. Default is HTTP in
the accepted isolated LAN. Session cookie follows session contract (`HttpOnly`,
`SameSite=Strict`, `Secure=false`); deploy prints a warning that public or
untrusted networks require an explicitly configured HTTPS reverse proxy, not a
silent security claim. `PUBLIC_ORIGIN=http://<LAN-host>:8090` is required and
used for exact Origin/CSRF validation. CORS is disabled by default.

Persistent named volume `mgkct_data` mounts only `/pb/pb_data`. Images, build
outputs, temporary test dirs and app container filesystem are disposable. No
service password, token or data directory is committed. `.env.example` supplies
names/placeholders only: `PB_SERVICE_EMAIL`, `PB_SERVICE_PASSWORD`,
`APP_PORT`, `APP_BIND`, `PB_HOST_PORT`, `PUBLIC_ORIGIN`, `NO_PROXY` and optional
image overrides for tests. Production `.env` is mode 0600 and ignored.

## Canonical scripts

`scripts/check.sh [--help]` is local/CI verification entry point. It checks
tools and versions, formatting, analysis, PB schema tests, server tests/build,
client tests/release Web build, and the isolated smoke; after Task 23 it also
runs E2E. Every skipped/missing prerequisite is failure, returns nonzero, and
the script contains no secrets or persistent data paths.

`scripts/deploy.sh [--help]` is the only Podman deployment entry point. It
supports `up`, `status`, `logs`, `stop`, `down` and `--self-test`; unsupported
arguments return 64, preflight/config failure 2, readiness failure 3 and child
command failures retain a nonzero code. `up` is idempotent: validates `.env`,
builds pinned images, creates network/volume if absent, migrates clean schema,
starts/replaces containers without deleting `mgkct_data`, waits boundedly for
PB then `GET /api/health`, and prints no secret. `down` stops containers but
keeps volume.

`--self-test` uses a generated temporary project dir, random temporary volume,
temporary credentials and random loopback port; it performs first `up`, health,
second `up`, health, cleanup. It never reads working `.env`, named volume or
PB data. Task 25 writes it and records output in deploy QA.

Reset is an explicit development-only command `scripts/deploy.sh reset-dev
--data-dir ABSOLUTE_PATH --confirm RESET_DEVELOPMENT_DATA`. It rejects a missing,
relative, root, home, repository, volume or unrecognised path; requires marker
file created by deploy self-test/dev init; stops only its identified temporary
stack then removes that exact directory. Normal `up` never resets or migrates
legacy data. First production start requires an empty/new declared volume;
legacy database migration is not supported.

## Readiness and operations

PB starts first and exposes internal health; app performs schema readiness
before bind. Deploy polls boundedly (for example 60 attempts × 1 s) then calls
public same-origin `/api/health`; failure prints container logs tail and exits
3. `status` shows container health and public URL; `logs` delegates bounded
Podman logs; stop/restart do not rotate credentials or invalidate sessions
stored in PB. `NO_PROXY` always includes loopback and Podman names to avoid
proxying internal DNS.

## CI

Git remote is GitHub, so Task 26 uses GitHub Actions and invokes `scripts/check.sh`.
Network probing of `git ls-remote origin` on 2026-09-17 could not verify runner
access because local SSH known_hosts permission/host-key validation failed;
this is not evidence that Actions is unavailable. Task 26 must verify workflow
on a branch/PR and publish server/Web artifacts. Remote CD, server address and
credentials remain out of scope.

## Verification

Manual trace: clean host needs Podman, repo checkout, local PB binary and `.env`;
first up creates only named volume/network, repeat up preserves it, health
checks Shelf and PB, down keeps data. `podman --version` passed, Docker was not
found, and PB binary/version/SHA passed. Implementation deliberately remains
Task 22/25/26; this contract changed no runtime files.
