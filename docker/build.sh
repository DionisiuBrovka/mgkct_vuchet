#!/usr/bin/env bash
# Сборка и запуск контейнера «Вычитка».
# Автоопределяет движок:
#   • podman (локальная разработка) — прямые podman build/run (compose-провайдер
#     rootless не работает с -f docker/docker-compose.yml);
#   • docker  (production)          — docker compose.
# Пароль суперюзера (передаётся в контейнер при первом запуске): задайте
# переменную окружения PB_ADMIN_PASSWORD или введите в ответ на приглашение.
# Запуск:  bash docker/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# ── Общие параметры ─────────────────────────────────────────
IMAGE="mgkct_teaching_hours:latest"
CONTAINER="mgkct"
VOLUME="mgkct_data"
PORT="8090"
COMPOSE_FILE="docker/docker-compose.yml"
SUPERUSER_EMAIL="${PB_SUPERUSER_EMAIL:-admin@mgkct.local}"

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

# ── Пароль суперюзера ───────────────────────────────────────
ADMIN_PASS="${PB_ADMIN_PASSWORD:-}"
if [ -z "$ADMIN_PASS" ]; then
  echo "▸ Пароль суперюзера $SUPERUSER_EMAIL (для входа в /_/):"
  read -rsp "Пароль: " ADMIN_PASS; echo
  read -rsp "Повторите: " ADMIN_PASS2; echo
  if [ "$ADMIN_PASS" != "$ADMIN_PASS2" ]; then
    echo "✗ Пароли не совпадают."
    exit 1
  fi
fi

# ── Сборка образа (Flutter Web + PocketBase) ────────────────
echo "▸ Сборка образа..."
if [ "$ENGINE" = "docker" ]; then
  $ENGINE compose -f "$COMPOSE_FILE" build
else
  $ENGINE build -f docker/Dockerfile -t "$IMAGE" .
fi

# ── Запуск (сев тестовых данных выполнит entrypoint при 1-м старте) ──
echo "▸ Запуск контейнера..."
if [ "$ENGINE" = "docker" ]; then
  $ENGINE rm -f "$CONTAINER" >/dev/null 2>&1 || true
  $ENGINE compose -f "$COMPOSE_FILE" up -d
else
  $ENGINE rm -f "$CONTAINER" >/dev/null 2>&1 || true
  $ENGINE run -d --name "$CONTAINER" -p "$PORT:8090" \
    -e "PB_ADMIN_PASSWORD=$ADMIN_PASS" \
    -e "PB_SUPERUSER_EMAIL=$SUPERUSER_EMAIL" \
    -v "$VOLUME:/pb/pb_data" "$IMAGE"
fi

echo "▸ Статус:"
if [ "$ENGINE" = "docker" ]; then
  $ENGINE compose -f "$COMPOSE_FILE" ps
else
  $ENGINE ps --filter "name=$CONTAINER"
fi
