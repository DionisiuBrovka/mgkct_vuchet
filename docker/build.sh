#!/usr/bin/env bash
# Сборка и запуск контейнера «Вычитка».
# Автоопределяет движок: локально — podman, на проде — docker (тот же compose-файл).
# Запуск:  bash docker/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# ── Определяем движок контейнеров ──────────────────────────
ENGINE=""
if command -v podman >/dev/null 2>&1; then
  ENGINE="podman"
elif command -v docker >/dev/null 2>&1; then
  ENGINE="docker"
else
  echo "✗ Ни podman, ни docker не найдены. Установите один из них."
  exit 1
fi

COMPOSE_FILE="docker/docker-compose.yml"
COMPOSE="$ENGINE compose -f $COMPOSE_FILE"

echo "▸ Движок: $ENGINE"

# ── Сборка образа (Flutter Web + PocketBase) ──────────────
echo "▸ Сборка образа..."
$COMPOSE build

# ── Создание суперюзера (один раз, интерактивно) ──────────
echo "▸ Создание суперюзера admin@mgkct.local (введите пароль)..."
$COMPOSE run --rm mgkct /pb/pocketbase superuser upsert admin@mgkct.local

# ── Запуск ─────────────────────────────────────────────────
echo "▸ Запуск сервиса..."
$COMPOSE up -d

echo "▸ Статус:"
$COMPOSE ps
