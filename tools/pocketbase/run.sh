#!/usr/bin/env bash
# Запуск локального PocketBase для разработки.
# Используйте: bash run.sh
#
# --automigrate=false — обязателен: без него PocketBase при serve сам меняет
# схему и ломает коллекции (известная проблема этого проекта).
set -e
cd "$(dirname "$0")"

# Применить миграции схемы (безопасно повторно — уже применённые игнорируются).
./pocketbase migrate up --automigrate=false

exec ./pocketbase serve --http=127.0.0.1:8090 --automigrate=false
