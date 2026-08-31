#!/usr/bin/env bash
set -euo pipefail
DATA_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$DATA_ROOT/../.." && pwd)"
# Preserve the existing development database; do not silently start an empty one.
DEFAULT_DATA="$DATA_ROOT/pb_data"
if [ -d "$PROJECT_ROOT/tools/pocketbase/pb_data" ]; then
  DEFAULT_DATA="$PROJECT_ROOT/tools/pocketbase/pb_data"
fi
DATA_DIR="${PB_DATA_DIR:-$DEFAULT_DATA}"
PB_BIN="${POCKETBASE_BIN:-$DATA_ROOT/pocketbase}"
"$PB_BIN" migrate up --dir="$DATA_DIR" --migrationsDir="$DATA_ROOT/pb_migrations" --automigrate=false
exec "$PB_BIN" serve --dir="$DATA_DIR" --migrationsDir="$DATA_ROOT/pb_migrations" \
  --hooksDir="$DATA_ROOT/pb_hooks" --http="${PB_HTTP:-127.0.0.1:8090}" --automigrate=false
