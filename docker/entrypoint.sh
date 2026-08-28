#!/bin/sh
# Точка входа для контейнера PocketBase.
# Сначала применяет миграции схемы (безопасно при каждом старте — уже применённые
# игнорируются), затем запускает сервер.
set -e

echo "[entrypoint] Applying migrations..."
/pb/pocketbase migrate up --automigrate=false

echo "[entrypoint] Starting PocketBase..."
exec /pb/pocketbase serve --http=0.0.0.0:8090 --automigrate=false
