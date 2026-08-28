# syntax=docker/dockerfile:1
# ────────────────────────────────────────────────────────────
# Единый контейнер «Вычитка»: PocketBase (API + база) + Flutter Web
# ────────────────────────────────────────────────────────────
# Этап 1: сборка Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS web-builder

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

# ────────────────────────────────────────────────────────────
# Этап 2: рантайм PocketBase
FROM alpine:3.20 AS runtime

# PocketBase — статический Go-бинарник, достаточно базового аляйна.
RUN apk add --no-cache curl

WORKDIR /pb

# Скопировать бинарник PocketBase (собран на Linux/amd64)
COPY tools/pocketbase/pocketbase /pb/pocketbase
RUN chmod +x /pb/pocketbase

# Миграции схемы
COPY tools/pocketbase/pb_migrations /pb/pb_migrations

# Веб-сборка Flutter → pb_public (PocketBase раздаёт её по /
COPY --from=web-builder /app/build/web /pb/pb_public

# Том для данных (база + файлы)
VOLUME ["/pb/pb_data"]

ENV PB_DATA_DIR=/pb/pb_data

# Точка входа: применяет миграции, затем запускает сервер.
ENV POCKETBASE_HOME=/pb
COPY docker/entrypoint.sh /pb/entrypoint.sh
RUN chmod +x /pb/entrypoint.sh

EXPOSE 8090

# --http=0.0.0.0:8090 — слушать все интерфейсы (доступ по сети).
CMD ["/pb/entrypoint.sh"]
