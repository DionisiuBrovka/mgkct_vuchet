#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PB_VERSION='0.40.1'
PB_SHA256='bfdc715d14d922f3dfcb8333cc439e7eb1d44ed602456662299bf14f4d6387b8'
PB_BINARY="$ROOT/data/pocketbase/pocketbase"
PB_URL="https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip"

if [[ -x "$PB_BINARY" ]] && [[ "$(sha256sum "$PB_BINARY" | awk '{print $1}')" == "$PB_SHA256" ]]; then
  exit 0
fi

command -v curl >/dev/null || { echo 'Missing required tool: curl' >&2; exit 1; }
command -v unzip >/dev/null || { echo 'Missing required tool: unzip' >&2; exit 1; }

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mgkct-pocketbase.XXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT INT TERM
curl --fail --location --silent --show-error --output "$TMP_DIR/pocketbase.zip" "$PB_URL"
unzip -p "$TMP_DIR/pocketbase.zip" pocketbase >"$TMP_DIR/pocketbase"
test "$(sha256sum "$TMP_DIR/pocketbase" | awk '{print $1}')" = "$PB_SHA256" || {
  echo 'PocketBase checksum mismatch.' >&2
  exit 1
}
chmod 0555 "$TMP_DIR/pocketbase"
mv "$TMP_DIR/pocketbase" "$PB_BINARY"
"$PB_BINARY" --version | grep -Fq "$PB_VERSION" || {
  echo 'PocketBase version mismatch.' >&2
  exit 1
}
