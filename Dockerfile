# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 ghcr.io/cirruslabs/flutter:3.44.0 AS client-builder
WORKDIR /client
COPY client/pubspec.yaml client/pubspec.lock ./
RUN flutter pub get
COPY client/ ./
RUN flutter build web --release

FROM --platform=linux/amd64 dart:3.12.2-sdk AS server-builder
WORKDIR /server
COPY server/pubspec.yaml server/pubspec.lock ./
RUN dart pub get
COPY server/ ./
RUN mkdir -p /out && dart compile exe bin/server.dart -o /out/server

FROM --platform=linux/amd64 debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=server-builder /out/server /app/server
COPY --from=client-builder /client/build/web /app/public
ENV HOST=0.0.0.0 PORT=8080 STATIC_DIR=/app/public
USER 65534:65534
EXPOSE 8080
CMD ["/app/server"]
