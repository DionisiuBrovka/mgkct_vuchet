#!/bin/sh
set -eu
: "${PB_SERVICE_EMAIL:?Set PB_SERVICE_EMAIL}"
: "${PB_SERVICE_PASSWORD:?Set PB_SERVICE_PASSWORD}"
case "$PB_SERVICE_PASSWORD" in replace-with-*|'') echo "Set a non-placeholder PB_SERVICE_PASSWORD." >&2; exit 2;; esac
/pb/pocketbase migrate up --dir=/pb/pb_data --migrationsDir=/pb/pb_migrations --automigrate=false
/pb/pocketbase superuser upsert "$PB_SERVICE_EMAIL" "$PB_SERVICE_PASSWORD" --dir=/pb/pb_data --migrationsDir=/pb/pb_migrations --automigrate=false >/dev/null
exec /pb/pocketbase serve --http=0.0.0.0:8090 --dir=/pb/pb_data --migrationsDir=/pb/pb_migrations --hooksDir=/pb/pb_hooks --automigrate=false
