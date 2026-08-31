#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then set -a; source .env; set +a; fi
: "${PB_SERVICE_EMAIL:?Set PB_SERVICE_EMAIL in .env or environment}"
: "${PB_SERVICE_PASSWORD:?Set PB_SERVICE_PASSWORD in .env or environment}"
case "$PB_SERVICE_PASSWORD" in replace-with-*) echo "Replace the example service password before startup." >&2; exit 1;; esac
# Podman inherits host proxy settings; internal container DNS must bypass them.
internal_no_proxy="${NO_PROXY:-},${no_proxy:-},localhost,127.0.0.1,::1,pocketbase,mgkct_data_store,mgkct"
if command -v docker >/dev/null 2>&1; then
  docker compose -f docker-compose.yml build
  # Stop the old single-container deployment before reusing its database volume.
  docker compose -f docker-compose.yml stop mgkct
  docker compose -f docker-compose.yml up -d
elif command -v podman >/dev/null 2>&1; then
  podman build -f Dockerfile -t mgkct_teaching_hours:latest .
  podman build -f pocketbase.Dockerfile -t mgkct_data:latest .
  podman network exists mgkct_network || podman network create mgkct_network
  podman rm -f mgkct mgkct_data_store >/dev/null 2>&1 || true
  podman run -d --name mgkct_data_store --network mgkct_network --network-alias pocketbase \
    -e "NO_PROXY=$internal_no_proxy" -e "no_proxy=$internal_no_proxy" \
    -p 127.0.0.1:8091:8090 -v mgkct_data:/pb/pb_data \
    -e PB_SERVICE_EMAIL -e PB_SERVICE_PASSWORD --restart unless-stopped mgkct_data:latest
  # The API fails fast if data is not ready; the restart policy retries startup.
  podman run -d --name mgkct --network mgkct_network -p 8090:8080 \
    -e "NO_PROXY=$internal_no_proxy" -e "no_proxy=$internal_no_proxy" \
    -e POCKETBASE_URL=http://pocketbase:8090 -e PB_SERVICE_EMAIL -e PB_SERVICE_PASSWORD \
    --restart unless-stopped mgkct_teaching_hours:latest
else
  echo 'Install Docker Compose or Podman.' >&2
  exit 1
fi
