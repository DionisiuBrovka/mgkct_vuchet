#!/usr/bin/env bash
# Explicit initialization/rotation of the server service account; no demo accounts.
set -euo pipefail
: "${PB_SERVICE_EMAIL:?Set PB_SERVICE_EMAIL}"
: "${PB_SERVICE_PASSWORD:?Set PB_SERVICE_PASSWORD}"
case "$PB_SERVICE_PASSWORD" in replace-with-*) echo "Replace the example service password before startup." >&2; exit 1;; esac
DATA_ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${PB_DATA_DIR:?Set PB_DATA_DIR explicitly.}"
exec "${POCKETBASE_BIN:-$DATA_ROOT/pocketbase}" superuser upsert "$PB_SERVICE_EMAIL" "$PB_SERVICE_PASSWORD" \
  --dir="$PB_DATA_DIR" --migrationsDir="$DATA_ROOT/pb_migrations" --automigrate=false
