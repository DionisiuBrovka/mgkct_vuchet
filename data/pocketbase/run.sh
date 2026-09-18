#!/usr/bin/env bash
set -euo pipefail
DATA_ROOT="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${PB_DATA_DIR:?Set PB_DATA_DIR explicitly; this script never selects a legacy database.}"
PB_BIN="${POCKETBASE_BIN:-$DATA_ROOT/pocketbase}"
[[ "$DATA_DIR" = /* ]] || { echo 'PB_DATA_DIR must be an absolute path.' >&2; exit 2; }
"$PB_BIN" migrate up --dir="$DATA_DIR" --migrationsDir="$DATA_ROOT/pb_migrations" --automigrate=false
exec "$PB_BIN" serve --dir="$DATA_DIR" --migrationsDir="$DATA_ROOT/pb_migrations" \
  --hooksDir="$DATA_ROOT/pb_hooks" --http="${PB_HTTP:-127.0.0.1:8090}" --automigrate=false
