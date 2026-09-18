#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
usage() { cat <<'EOF'
Usage: bash scripts/deploy.sh [up|status|logs|stop|down|--self-test]

Uses Podman and .env to deploy the Web/Shelf and PocketBase containers. `down`
keeps persistent data. `--self-test` is isolated and never reads .env.
EOF
}
die() { echo "$*" >&2; exit 2; }
need() { command -v "$1" >/dev/null || die "Missing required tool: $1"; }
[[ "${1:-up}" == '--help' ]] && { usage; exit 0; }
need podman
[[ "$(uname -m)" == x86_64 ]] || die 'PocketBase runtime requires x86_64.'
[[ "$(sha256sum data/pocketbase/pocketbase | awk '{print $1}')" == bfdc715d14d922f3dfcb8333cc439e7eb1d44ed602456662299bf14f4d6387b8 ]] || die 'PocketBase checksum mismatch.'
cmd="${1:-up}"
[[ $# -le 1 ]] || die 'Unsupported arguments.'
if [[ "$cmd" == '--self-test' ]]; then
  need python3
  test_root="$(mktemp -d "${TMPDIR:-/tmp}/mgkct-deploy-test.XXXXXX")"
  test_id="task25-$$-$(date +%s)"
  test_network="${test_id}-network"
  test_volume="${test_id}-data"
  test_pb="${test_id}-pb"
  test_app="${test_id}-app"
  test_port="$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()
PY
)"
  test_password="test-$(sha256sum <<<"$test_id" | cut -c1-32)"
  cleanup_test() {
    podman rm -f "$test_app" "$test_pb" >/dev/null 2>&1 || true
    podman network rm "$test_network" >/dev/null 2>&1 || true
    podman volume rm "$test_volume" >/dev/null 2>&1 || true
    rm -rf -- "$test_root"
  }
  trap cleanup_test EXIT INT TERM
  podman build -f Dockerfile -t "${test_id}-app" .
  podman build -f pocketbase.Dockerfile -t "${test_id}-pb" .
  podman network create "$test_network" >/dev/null
  podman volume create "$test_volume" >/dev/null
  podman run -d --name "$test_pb" --network "$test_network" --network-alias pocketbase -v "$test_volume":/pb/pb_data -e PB_SERVICE_EMAIL=test@example.invalid -e PB_SERVICE_PASSWORD="$test_password" "${test_id}-pb" >/dev/null
  for _ in $(seq 1 60); do podman exec "$test_pb" wget -qO- http://127.0.0.1:8090/api/health >/dev/null 2>&1 && break; sleep 1; done
  podman exec "$test_pb" wget -qO- http://127.0.0.1:8090/api/health >/dev/null || exit 3
  origin="http://127.0.0.1:$test_port"
  podman run -d --name "$test_app" --network "$test_network" -p "127.0.0.1:$test_port:8080" -e POCKETBASE_URL=http://pocketbase:8090 -e PB_SERVICE_EMAIL=test@example.invalid -e PB_SERVICE_PASSWORD="$test_password" -e PUBLIC_ORIGIN="$origin" "${test_id}-app" >/dev/null
  for _ in $(seq 1 60); do curl -fsS "$origin/api/health" >/dev/null 2>&1 && break; sleep 1; done
  curl -fsS "$origin/api/health" >/dev/null || exit 3
  podman restart "$test_app" >/dev/null
  curl -fsS "$origin/api/health" >/dev/null || exit 3
  echo 'Isolated deploy self-test passed.'
  exit 0
fi
case "$cmd" in
  up)
    [[ -f .env ]] || die 'Missing .env; copy .env.example and set values.'
    set -a; source .env; set +a
    : "${PB_SERVICE_EMAIL:?}"; : "${PB_SERVICE_PASSWORD:?}"; : "${PUBLIC_ORIGIN:?}"
    [[ "$PB_SERVICE_PASSWORD" != replace-with-* ]] || die 'Replace PB_SERVICE_PASSWORD.'
    podman build -f Dockerfile -t mgkct-app:local .
    podman build -f pocketbase.Dockerfile -t mgkct-pb:local .
    podman network exists mgkct_network || podman network create mgkct_network
    podman volume exists mgkct_data || podman volume create mgkct_data >/dev/null
    podman rm -f mgkct-app mgkct-pb >/dev/null 2>&1 || true
    podman run -d --name mgkct-pb --network mgkct_network --network-alias pocketbase -p "127.0.0.1:${PB_HOST_PORT:-8091}:8090" -v mgkct_data:/pb/pb_data -e PB_SERVICE_EMAIL -e PB_SERVICE_PASSWORD mgkct-pb:local >/dev/null
    for _ in $(seq 1 60); do podman exec mgkct-pb wget -qO- http://127.0.0.1:8090/api/health >/dev/null 2>&1 && break; sleep 1; done
    podman exec mgkct-pb wget -qO- http://127.0.0.1:8090/api/health >/dev/null || { podman logs --tail 50 mgkct-pb >&2; exit 3; }
    podman run -d --name mgkct-app --network mgkct_network -p "${APP_BIND:-0.0.0.0}:${APP_PORT:-8090}:8080" -e POCKETBASE_URL=http://pocketbase:8090 -e PB_SERVICE_EMAIL -e PB_SERVICE_PASSWORD -e PUBLIC_ORIGIN mgkct-app:local >/dev/null
    for _ in $(seq 1 60); do curl -fsS "${PUBLIC_ORIGIN}/api/health" >/dev/null 2>&1 && break; sleep 1; done
    curl -fsS "${PUBLIC_ORIGIN}/api/health" || { podman logs --tail 50 mgkct-app >&2; exit 3; }
    echo "Ready: $PUBLIC_ORIGIN";;
  status) podman ps --filter name=mgkct-;;
  logs) podman logs --tail 100 mgkct-app; podman logs --tail 100 mgkct-pb;;
  stop) podman stop mgkct-app mgkct-pb;;
  down) podman rm -f mgkct-app mgkct-pb;;
  *) usage >&2; exit 64;;
esac
