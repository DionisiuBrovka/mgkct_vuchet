#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHECK_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mgkct-check.XXXXXX")"
trap 'rm -rf -- "$CHECK_TMP"' EXIT INT TERM

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: bash scripts/check.sh

Runs formatting checks, server/PocketBase/client tests and release Web build.
The script does not load .env and never uses a working PB_DATA_DIR.
EOF
  exit 0
fi

stage() { printf '\n==> %s\n' "$1"; }
need() { command -v "$1" >/dev/null || { echo "Missing required tool: $1" >&2; exit 1; }; }
version_contains() {
  local command="$1" expected="$2"; shift 2
  "$command" "$@" 2>&1 | grep -Fq "$expected" || {
    echo "Unexpected $command version; expected $expected" >&2
    exit 1
  }
}

for tool in dart flutter python3; do need "$tool"; done
[[ -x data/pocketbase/pocketbase ]] || { echo "Missing PocketBase binary" >&2; exit 1; }
version_contains dart '3.12.2' --version
version_contains flutter 'Flutter 3.44.8' --version
version_contains data/pocketbase/pocketbase '0.40.1' --version

stage 'PocketBase schema tests'
python3 -m unittest data/pocketbase/tests/test_report_storage.py
stage 'Server format and tests'
(cd server && dart format --output=none --set-exit-if-changed lib bin test && dart analyze && dart test)
stage 'Server release executable'
(cd server && dart compile exe bin/server.dart -o "$CHECK_TMP/server")
stage 'Client format, tests and release build'
(cd client && dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test && flutter build web --release)
stage 'Diff whitespace'
git diff --check
printf '\nAll local checks passed.\n'
