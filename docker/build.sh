#!/usr/bin/env bash
# Сборка и запуск контейнера «Вычитка».
# Автоопределяет движок:
#   • podman (локальная разработка) — прямые podman build/run (compose-провайдер
#     rootless не работает с -f docker/docker-compose.yml);
#   • docker  (production)          — docker compose.
# Пароль суперюзера: передайте через переменную окружения PB_ADMIN_PASSWORD
# (удобно для скриптов) либо введите в ответ на приглашение.
# Запуск:  bash docker/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# ── Общие параметры ─────────────────────────────────────────
IMAGE="mgkct_vuchet:latest"
CONTAINER="mgkct"
VOLUME="mgkct_data"
PORT="8090"
COMPOSE_FILE="docker/docker-compose.yml"
SUPERUSER_EMAIL="admin@mgkct.local"

# ── Определяем движок ───────────────────────────────────────
ENGINE=""
if command -v podman >/dev/null 2>&1; then
  ENGINE="podman"
elif command -v docker >/dev/null 2>&1; then
  ENGINE="docker"
else
  echo "✗ Ни podman, ни docker не найдены. Установите один из них."
  exit 1
fi
echo "▸ Движок: $ENGINE"

# ── Сборка образа (Flutter Web + PocketBase) ────────────────
echo "▸ Сборка образа..."
if [ "$ENGINE" = "docker" ]; then
  $ENGINE compose -f "$COMPOSE_FILE" build
else
  $ENGINE build -f docker/Dockerfile -t "$IMAGE" .
fi

# ── Создание суперюзера (один раз, интерактивно) ──────────
ADMIN_PASS="${PB_ADMIN_PASSWORD:-}"
if [ -z "$ADMIN_PASS" ]; then
  echo "▸ Создание суперюзера $SUPERUSER_EMAIL..."
  read -rsp "Пароль суперюзера: " ADMIN_PASS; echo
  read -rsp "Повторите пароль: " ADMIN_PASS2; echo
  if [ "$ADMIN_PASS" != "$ADMIN_PASS2" ]; then
    echo "✗ Пароли не совпадают. Повторите запуск."
    exit 1
  fi
fi

if [ "$ENGINE" = "docker" ]; then
  $ENGINE compose -f "$COMPOSE_FILE" run --rm "$CONTAINER" \
    /pb/pocketbase superuser upsert "$SUPERUSER_EMAIL" "$ADMIN_PASS"
else
  $ENGINE run -i --rm -v "$VOLUME:/pb/pb_data" "$IMAGE" \
    /pb/pocketbase superuser upsert "$SUPERUSER_EMAIL" "$ADMIN_PASS"
fi

# ── Запуск ─────────────────────────────────────────────────
echo "▸ Запуск контейнера..."
if [ "$ENGINE" = "docker" ]; then
  $ENGINE compose -f "$COMPOSE_FILE" up -d
else
  # удалить старый, если есть, и запустить поверх того же тома
  $ENGINE rm -f "$CONTAINER" >/dev/null 2>&1 || true
  $ENGINE run -d --name "$CONTAINER" -p "$PORT:8090" -v "$VOLUME:/pb/pb_data" "$IMAGE"
fi

echo "▸ Статус:"
if [ "$ENGINE" = "docker" ]; then
  $ENGINE compose -f "$COMPOSE_FILE" ps
else
  $ENGINE ps --filter "name=$CONTAINER"
fi
