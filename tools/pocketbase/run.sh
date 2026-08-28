#!/usr/bin/env bash
# Запуск локального PocketBase для разработки.
# Используйте: bash run.sh
set -e
cd "$(dirname "$0")"
exec ./pocketbase serve --http=127.0.0.1:8090
