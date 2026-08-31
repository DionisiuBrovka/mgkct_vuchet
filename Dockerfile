# syntax=docker/dockerfile:1
FROM ghcr.io/cirruslabs/flutter:stable AS client-builder
WORKDIR /client
COPY client/pubspec.yaml client/pubspec.lock ./
RUN flutter pub get
COPY client/ ./
RUN flutter build web --release

FROM dart:stable AS server-builder
WORKDIR /server
COPY server/pubspec.yaml server/pubspec.lock ./
RUN dart pub get
COPY server/ ./
RUN mkdir -p /out && dart compile exe bin/server.dart -o /out/server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=server-builder /out/server /app/server
COPY --from=client-builder /client/build/web /app/public
ENV HOST=0.0.0.0 PORT=8080 STATIC_DIR=/app/public
USER 65534:65534
EXPOSE 8080
CMD ["/app/server"]
