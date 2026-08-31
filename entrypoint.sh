#!/bin/sh
set -eu
: "${PB_SERVICE_EMAIL:?Set PB_SERVICE_EMAIL}"
: "${PB_SERVICE_PASSWORD:?Set PB_SERVICE_PASSWORD}"
case "$PB_SERVICE_PASSWORD" in replace-with-*) echo "Replace the example service password before startup." >&2; exit 1;; esac
/pb/pocketbase migrate up --dir=/pb/pb_data --automigrate=false
/pb/pocketbase superuser upsert "$PB_SERVICE_EMAIL" "$PB_SERVICE_PASSWORD" --dir=/pb/pb_data --automigrate=false >/dev/null
exec /pb/pocketbase serve --http=0.0.0.0:8090 --dir=/pb/pb_data --hooksDir=/pb/pb_hooks --automigrate=false
