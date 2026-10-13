# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 docker.io/library/debian:trixie-slim AS client-builder
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*
RUN curl --fail --location --retry 3 --output /tmp/flutter.tar.xz \
      https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.8-stable.tar.xz \
    && echo '672089e001571a9fbb209a495c583580c0c6c73ef98999264ba07fa93ace332d  /tmp/flutter.tar.xz' | sha256sum --check \
    && tar -xf /tmp/flutter.tar.xz -C /opt --no-same-owner \
    && rm /tmp/flutter.tar.xz
ENV PATH="/opt/flutter/bin:${PATH}"
WORKDIR /client
COPY client/pubspec.yaml client/pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY client/ ./
RUN flutter build web --release

FROM --platform=linux/amd64 docker.io/library/dart:3.12.2-sdk AS server-builder
WORKDIR /server
COPY server/pubspec.yaml server/pubspec.lock ./
RUN dart pub get --enforce-lockfile
COPY server/ ./
RUN mkdir -p /out && dart compile exe bin/server.dart -o /out/server

FROM --platform=linux/amd64 docker.io/library/debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=server-builder /out/server /app/server
COPY --from=client-builder /client/build/web /app/public
ENV HOST=0.0.0.0 PORT=8080 STATIC_DIR=/app/public
USER 65534:65534
EXPOSE 8080
CMD ["/app/server"]
