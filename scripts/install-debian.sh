#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
usage() {
  cat <<'HELP'
Установка «Вычитки» на Debian 13 x86_64 без контейнеров.
  sudo bash scripts/deploy.sh debian
  sudo bash scripts/deploy.sh debian --origin http://192.168.1.10:8090
Повторный запуск обновляет код, сохраняя данные и пароли.
Первый запуск без --origin запрашивает адрес приложения в локальной сети.
HELP
}
ORIGIN=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0;;
    --origin) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; ORIGIN="$2"; shift 2;;
    *) usage >&2; exit 2;;
  esac
done
[[ $EUID -eq 0 ]] || { echo 'Запустите скрипт через sudo или от root.' >&2; exit 2; }
# This installer owns fixed system paths; never import a checkout's .env.
source /etc/os-release
[[ "$ID" == debian && "$VERSION_ID" == 13 ]] || { echo 'Требуется Debian 13.' >&2; exit 2; }
[[ "$(uname -m)" == x86_64 ]] || { echo 'Поддерживается только x86_64 (amd64).' >&2; exit 2; }
[[ -d /run/systemd/system ]] || { echo 'Требуется работающий systemd.' >&2; exit 2; }
exec 9>/run/lock/mgkct-install.lock
flock -n 9 || { echo 'Установка уже выполняется.' >&2; exit 2; }
for path in client/pubspec.lock server/pubspec.lock scripts/debian/configure.py; do
  [[ -f "$ROOT/$path" ]] || { echo "Неполная копия проекта: $path" >&2; exit 2; }
done
if [[ ! -f /etc/mgkct/install.json && -z "$ORIGIN" ]]; then
  [[ -t 0 ]] || { echo 'Для первого запуска укажите --origin http://IP-СЕРВЕРА:8090' >&2; exit 2; }
  suggested_ip="$(hostname -I | awk '{print $1}')"
  read -r -p "Адрес приложения [http://${suggested_ip:-127.0.0.1}:8090]: " ORIGIN
  ORIGIN="${ORIGIN:-http://${suggested_ip:-127.0.0.1}:8090}"
fi
if [[ -f /var/lib/mgkct/pb_data/data.db && ! -f /etc/mgkct/install.json ]]; then
  echo 'Обнаружена база без конфигурации установщика. Автоматическое подключение отменено.' >&2
  exit 2
fi
stopped=false
trap 'code=$?; if (( code != 0 )); then echo "Установка не завершена (код $code)." >&2; if $stopped; then echo "Службы могут быть остановлены. Данные сохранены; копии: /var/backups/mgkct. Исправьте причину и повторите команду. Журнал: journalctl -u mgkct-app -u mgkct-pocketbase -n 100" >&2; fi; fi' EXIT
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils zip libglu1-mesa python3 rsync util-linux
for account in mgkct-build mgkct-app mgkct-pb; do
  if ! id "$account" >/dev/null 2>&1; then
    useradd --system --user-group --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin "$account"
  fi
done
install -d -m 0755 /opt/mgkct /opt/mgkct/releases /var/lib/mgkct
install -d -m 0700 /etc/mgkct /var/backups/mgkct
install -d -o mgkct-pb -g mgkct-pb -m 0700 /var/lib/mgkct/pb_data
install -d -o mgkct-build -g mgkct-build -m 0750 /var/cache/mgkct-build
python3 "$ROOT/scripts/debian/configure.py" configure /etc/mgkct "$ORIGIN"
APP_PORT="$(python3 "$ROOT/scripts/debian/configure.py" get /etc/mgkct port)"

# Build as a separate user with no access to runtime credentials or the database.
BUILD_ROOT=/var/cache/mgkct-build
SDK="$BUILD_ROOT/flutter-3.44.8"
if [[ ! -f "$SDK/.mgkct-verified" ]]; then
  archive="$BUILD_ROOT/flutter.tar.xz"
  curl --fail --location --retry 3 --output "$archive" https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.8-stable.tar.xz
  echo '672089e001571a9fbb209a495c583580c0c6c73ef98999264ba07fa93ace332d  '"$archive" | sha256sum --check --status
  sdk_temp="$(mktemp -d "$BUILD_ROOT/sdk.XXXXXX")"
  tar -xf "$archive" -C "$sdk_temp" --no-same-owner
  rm -rf -- "$SDK"
  mv "$sdk_temp/flutter" "$SDK"
  rmdir "$sdk_temp"
  rm -f "$archive"
  touch "$SDK/.mgkct-verified"
  chown -R mgkct-build:mgkct-build "$SDK"
fi
release_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
workspace="$BUILD_ROOT/source-$release_id"
install -d -o mgkct-build -g mgkct-build -m 0750 "$workspace"
for component in client server; do
  rsync -a --safe-links --exclude=.env --exclude='.env.*' --exclude=build --exclude=.dart_tool --exclude=.git \
    "$ROOT/$component/" "$workspace/$component/"
done
chown -R mgkct-build:mgkct-build "$workspace"
runuser -u mgkct-build -- env -i HOME="$BUILD_ROOT" PUB_CACHE="$BUILD_ROOT/pub-cache" PATH="$SDK/bin:/usr/bin:/bin" \
  bash -c 'set -euo pipefail
    cd "$1"
    flutter config --no-analytics
    dart --disable-analytics
    flutter --version | grep -F "Flutter 3.44.8"
    dart --version | grep -F "3.12.2"
    cd "$1/client"
    flutter pub get --enforce-lockfile
    flutter build web --release
    cd "$1/server"
    dart pub get --enforce-lockfile
    dart compile exe bin/server.dart -o "$1/server-executable"
  ' bash "$workspace"
bash "$ROOT/scripts/fetch-pocketbase.sh"
release="/opt/mgkct/releases/$release_id"
install -d -m 0755 "$release"
install -m 0755 "$workspace/server-executable" "$release/server"
install -m 0755 "$ROOT/data/pocketbase/pocketbase" "$release/pocketbase"
cp -R "$workspace/client/build/web" "$release/public"
cp -R "$ROOT/data/pocketbase/pb_migrations" "$ROOT/data/pocketbase/pb_hooks" "$release/"
chmod -R a+rX "$release"
chown -R root:root "$release"

# Check foreign port owners before stopping an existing installation.
python3 "$ROOT/scripts/debian/configure.py" ports /etc/mgkct
stopped=true
for unit in mgkct-app.service mgkct-pocketbase.service; do
  if [[ "$(systemctl show --property=LoadState --value "$unit")" != not-found ]]; then
    systemctl stop "$unit"
    if systemctl is-active --quiet "$unit"; then
      echo "Не удалось остановить $unit; копирование базы отменено." >&2
      exit 3
    fi
  fi
done
if [[ -f /var/lib/mgkct/pb_data/data.db ]]; then
  backup="/var/backups/mgkct/$release_id"
  install -d -m 0700 "$backup"
  tar -cf "$backup/pb_data.tar" -C /var/lib/mgkct pb_data
  cp -a /etc/mgkct "$backup/config"
  readlink -f /opt/mgkct/current > "$backup/release.txt" || true
  echo "Резервная копия: $backup"
fi
(cd /var/lib/mgkct && runuser -u mgkct-pb -- "$release/pocketbase" migrate up --dir=/var/lib/mgkct/pb_data \
  --migrationsDir="$release/pb_migrations" --automigrate=false)
if [[ ! -f /etc/mgkct/bootstrap-complete ]]; then
  python3 "$ROOT/scripts/debian/configure.py" superuser /etc/mgkct "$release/pocketbase"
fi
ln -sfn "$release" /opt/mgkct/current.next
mv -Tf /opt/mgkct/current.next /opt/mgkct/current
install -m 0644 "$ROOT/scripts/debian/mgkct-pocketbase.service" /etc/systemd/system/mgkct-pocketbase.service
install -m 0644 "$ROOT/scripts/debian/mgkct-app.service" /etc/systemd/system/mgkct-app.service
systemctl daemon-reload
systemctl enable mgkct-pocketbase.service mgkct-app.service
systemctl restart mgkct-pocketbase.service
wait_health() {
  for _ in $(seq 1 60); do
    curl --noproxy '*' --fail --silent --max-time 2 "$1" >/dev/null && return 0
    sleep 1
  done
  echo "Служба не готова: $1" >&2
  return 1
}
wait_health http://127.0.0.1:8091/api/health
python3 "$ROOT/scripts/debian/configure.py" bootstrap /etc/mgkct
systemctl restart mgkct-app.service
wait_health "http://127.0.0.1:$APP_PORT/api/health"
curl --noproxy '*' --fail --silent --max-time 10 "http://127.0.0.1:$APP_PORT/" >/dev/null
stopped=false
rm -rf -- "$workspace"
echo "Готово: $(python3 "$ROOT/scripts/debian/configure.py" get /etc/mgkct origin)"
echo 'Данные входа: sudo cat /etc/mgkct/credentials.txt'
echo 'PocketBase: SSH-туннель на порт 8091; инструкция в README.md.'
