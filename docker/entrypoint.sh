#!/bin/sh
# Точка входа для контейнера PocketBase.
# 1) Применяет миграции схемы.
# 2) Создаёт суперюзера (CLI, без сервера), если ещё нет.
# 3) Запускает сервер в фоне и, если коллекция users пуста, засевает тестовые
#    данные (учитель, админ, назначения) — только при первом запуске.
# 4) Запускает рабочий сервер в foreground.
set -e

PORT="${POCKETBASE_PORT:-8090}"
SUPERUSER_EMAIL="${PB_SUPERUSER_EMAIL:-admin@mgkct.local}"
SUPERUSER_PASSWORD="${PB_ADMIN_PASSWORD:-admin123456}"

echo "[entrypoint] Applying migrations..."
/pb/pocketbase migrate up --automigrate=false

# ── суперюзер — CLI до запуска сервера (upsert идемпотентен) ──
echo "[entrypoint] Ensuring superuser $SUPERUSER_EMAIL..."
/pb/pocketbase superuser upsert "$SUPERUSER_EMAIL" "$SUPERUSER_PASSWORD" >/dev/null

# ── запускаем сервер в фоне для возможного seed ────────────
/pb/pocketbase serve --http=127.0.0.1:$PORT --automigrate=false &
PB_PID=$!

# ждём готовности API
for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# token суперюзера
TOKEN=$(curl -sf -X POST "http://127.0.0.1:$PORT/api/collections/_superusers/auth-with-password" \
  -H 'Content-Type: application/json' \
  -d "{\"identity\":\"$SUPERUSER_EMAIL\",\"password\":\"$SUPERUSER_PASSWORD\"}" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
AUTH="Authorization: $TOKEN"
CT="Content-Type: application/json"

# ── тестовые данные, если коллекция users пуста ────────────
USERS_TOTAL=$(curl -sf "http://127.0.0.1:$PORT/api/collections/users/records?perPage=1" \
  -H "$AUTH" | grep -o '"totalItems":[0-9]*' | cut -d: -f2 || echo 0)

if [ -z "$USERS_TOTAL" ] || [ "$USERS_TOTAL" = "0" ]; then
  echo "[entrypoint] Seeding test data..."

  T=$(curl -s -X POST "http://127.0.0.1:$PORT/api/collections/users/records" \
    -H "$AUTH" -H "$CT" \
    -d '{"email":"teacher@mgkct.local","password":"teacher123","passwordConfirm":"teacher123","display_name":"Иванов И.И."}')
  TID=$(echo "$T" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

  A=$(curl -s -X POST "http://127.0.0.1:$PORT/api/collections/users/records" \
    -H "$AUTH" -H "$CT" \
    -d '{"email":"admin@mgkct.local","password":"admin123","passwordConfirm":"admin123","display_name":"Петрова А.А."}')
  AID=$(echo "$A" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

  TP=$(curl -s -X POST "http://127.0.0.1:$PORT/api/collections/user_profiles/records" \
    -H "$AUTH" -H "$CT" \
    -d "{\"user\":\"$TID\",\"role\":\"teacher\",\"display_name\":\"Иванов И.И.\",\"email\":\"teacher@mgkct.local\"}")
  TPID=$(echo "$TP" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

  AP=$(curl -s -X POST "http://127.0.0.1:$PORT/api/collections/user_profiles/records" \
    -H "$AUTH" -H "$CT" \
    -d "{\"user\":\"$AID\",\"role\":\"admin\",\"display_name\":\"Петрова А.А.\",\"email\":\"admin@mgkct.local\"}")
  APID=$(echo "$AP" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

  curl -s -X POST "http://127.0.0.1:$PORT/api/collections/assignments/records" \
    -H "$AUTH" -H "$CT" \
    -d "{\"teacher\":\"$TPID\",\"subject\":\"Математика\",\"group\":\"ПР-21\",\"year\":2026}" >/dev/null
  curl -s -X POST "http://127.0.0.1:$PORT/api/collections/assignments/records" \
    -H "$AUTH" -H "$CT" \
    -d "{\"teacher\":\"$TPID\",\"subject\":\"Физика\",\"group\":\"ПР-22\",\"year\":2026}" >/dev/null

  echo "[entrypoint] Seed done."
fi

# останавливаем временный сервер
kill "$PB_PID" 2>/dev/null || true
wait "$PB_PID" 2>/dev/null || true

echo "[entrypoint] Starting PocketBase (foreground)..."
exec /pb/pocketbase serve --http=0.0.0.0:$PORT --automigrate=false
