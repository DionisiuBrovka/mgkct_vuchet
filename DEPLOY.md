# Развёртывание «Вычитка» в локальной сети колледжа (production)

Стек: **Flutter/Web** (клиент) + **PocketBase** (бэкенд) на одном Linux-ПК, доступные
по локальной сети. Все преподаватели/админ заходят в приложение с браузеров своих
компьютеров/планшетов через адрес сервера, например `http://192.168.1.50:8090`.

> **Рекомендуется:** развёртывание через **Docker** (раздел 0 ниже) — меньше
> ручных шагов, автозапуск и бэкапы проще. Нативный способ (разделы 1–10) —
> запасной вариант без Docker.

---

## 0. Развёртывание через Docker (рекомендуется)

В репозитории уже лежат готовые файлы:

| Файл | Назначение |
|------|------------|
| `docker/Dockerfile` | Multi-stage образ: собирает Flutter Web, кладёт PocketBase + миграции + веб в один контейнер |
| `docker/docker-compose.yml` | Один сервис, том для базы, проброс порта 8090 |
| `docker/entrypoint.sh` | Применяет миграции, затем запускает сервер |
| `docker/build.sh` | Сборка + создание суперюзера + запуск |
| `.dockerignore` | Исключает лишнее из контекста сборки |

### 0.1. Требования на сервере

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # чтобы работать без sudo (выйти/войти заново)
```

### 0.2. Перед сборкой — настроить адрес сервера

Файл `lib/core/constants.dart`:

```dart
// Было (только локальная разработка):
// static const pocketBaseUrl = 'http://127.0.0.1:8090';
// Для прода — IP сервера колледжа:
static const pocketBaseUrl = 'http://192.168.1.50:8090';
```

> Замените на фактический статический IP сервера. Без этого другие машины сети
> не смогут подключиться.

### 0.3. Сборка и первый запуск

На машине, где есть **docker (или podman) + исходники проекта**:

```bash
bash docker/build.sh
```

`build.sh` сам определяет движок: локально — `podman`, на проде — `docker`
(compose-файл общий, результат — один и тот же образ). Проверено на
podman 5.x/Docker Compose v5.

Скрипт:
1. соберёт образ (Flutter Web + PocketBase в одном контейнере),
2. создаст суперюзера `admin@mgkct.local` (введёте пароль интерактивно),
3. запустит контейнер в фоне.

> **Важно про архитектуру:** бинарник `tools/pocketbase/pocketbase` — x86-64.
> Если сервер колледжа на ARM (например Raspberry Pi), скачайте
> `pocketbase_<версия>_linux_arm64.zip` с GitHub и замените бинарник в
> `tools/pocketbase/pocketbase` перед сборкой.

### 0.4. Проверка

```bash
# docker на проде, podman при локальной проверке — подставьте свой движок
docker compose -f docker/docker-compose.yml ps          # Up / Running
curl http://localhost:8090/api/health                    # API ok
# с другой машины сети:
curl http://<IP-сервера>:8090/api/health
# браузер: http://<IP-сервера>:8090/  → веб-приложение
#        : http://<IP-сервера>:8090/_/ → админка PocketBase
```

> В разделе ниже движок обозначен как `docker`; на локальной проверке с podman
> просто вызывайте `podman compose -f docker/docker-compose.yml ...`.

### 0.5. Полезные команды (Docker/Podman)

```bash
# Логи
docker compose -f docker/docker-compose.yml logs -f

# Перезапуск / остановка
docker compose -f docker/docker-compose.yml restart
docker compose -f docker/docker-compose.yml down      # (том данных сохранится)

# Обновить после изменения кода
bash docker/build.sh

# Резервная копия базы (том mgkct_data)
docker run --rm -v mgkct_data:/pb/pb_data -v /backup:/backup alpine \
  cp /pb/pb_data/data.db /backup/mgkct_$(date +%F).db
```

> **Локально на podman.** `build.sh` сам определяет движок: для `podman` он
> использует прямые `podman build`/`podman run` (в обход `podman compose`, чей
> внешний провайдер в rootless не работает), для `docker` — `docker compose`.
> Образ, собранный podman, полностью совместим с Docker — на проде достаточно
> `bash docker/build.sh` или `docker compose up -d --build`.

Данные хранятся в Docker-томе `mgkct_data` — они переживают пересоздание
контейнера. Для переноса на другой сервер скопируйте/экспортируйте этот том
(или `data.db` из него) — см. раздел 9 про бэкапы.

---

## 1. Архитектура развёртывания (нативный способ, без Docker)

```
┌─────────────┐         ┌──────────────────────────────┐
│ Браузер     │  HTTP   │ Linux-ПК (сервер колледжа)    │
│ преподава-  │ ──────► │  • PocketBase  (база + API)  │
│ теля/админа │         │  • Flutter Web (pb_public/)  │
└─────────────┘         └──────────────────────────────┘
   по локальной сети            http://<IP-сервера>:8090
```

- PocketBase отдаёт и **REST API**, и **веб-приложение** (через `pb_public`).
- Всё живёт на одной машине, отдельные веб/Nginx-серверы не нужны.

---

## 2. Предварительные требования на сервере (Linux/Ubuntu/Debian)

```bash
# Проверить версию ОС
lsb_release -a

# Убедиться, что сеть рабочая и известен IP сервера
hostname -I

# Установить curl (для проверок) и фиксированный IP проще задать заранее
sudo apt update && sudo apt install -y curl
```

> **Важно:** задайте серверу статический (фиксированный) IP в настройках сети/роутера,
> чтобы адрес не менялся после перезагрузок. Запишите его — он понадобится ниже.

---

## 3. Установка PocketBase

### 3.1. Скачать правильный бинарник для Linux (amd64)

Возьмите последнюю версию с https://github.com/pocketbase/pocketbase/releases —
файл вида `pocketbase_0.40.1_linux_amd64.zip` (та же версия уже используется,
проверьте актуальную на странице релизов).

```bash
# Создать каталог сервера
mkdir -p /opt/mgkct && cd /opt/mgkct

# Пример загрузки (подставьте актуальную версию/URL)
wget https://github.com/pocketbase/pocketbase/releases/download/v0.40.1/pocketbase_0.40.1_linux_amd64.zip
sudo apt install -y unzip
unzip pocketbase_0.40.1_linux_amd64.zip
chmod +x pocketbase

# Проверка
./pocketbase --version
```

> Если машина i686/arm — выберите соответствующий архив из списка релизов.

### 3.2. Скопировать миграции схемы

Каталог миграций должен лежать рядом с бинарником (или в `pb_migrations/` у запуска).

```bash
# Скопируйте из репозитория / инструментов на сервер
mkdir -p /opt/mgkct/pb_migrations
# Положите сюда tools/pocketbase/pb_migrations/1756000000000_init_collections.js
# (например, через scp/USB-флешку):
#   scp tools/pocketbase/pb_migrations/1756000000000_init_collections.js server:/opt/mgkct/pb_migrations/
```

### 3.3. Первичный запуск и применение миграций

```bash
cd /opt/mgkct
# Применить миграции схемы (создаст коллекции и поля)
./pocketbase migrate up --automigrate=false

# Создать суперюзера (администратора бэкенда) — один раз
./pocketbase superuser upsert admin@mgkct.local
#  → попросит ввести новый пароль. Запишите его в надёжное место.
```

> `--automigrate=false` обязателен: без него PocketBase при `serve` сам меняет
> схему и ломает коллекции (известная проблема этого проекта).

---

## 4. Сборка и размещение веб-версии (Flutter Web)

### 4.1. Настроить адрес сервера в приложении

Для работы веб-версии с других машин **обязательно** указать реальный адрес сервера,
а не `127.0.0.1`.

Файл: `lib/core/constants.dart`

```dart
// Было (только для локальной разработки):
// static const pocketBaseUrl = 'http://127.0.0.1:8090';

// Для прода — IP сервера колледжа:
static const pocketBaseUrl = 'http://192.168.1.50:8090';
```

> Подставьте фактический IP сервера из шага 2.
> Для Web PocketBase сам включает нужные CORS-заголовки (разрешает `*`), так что
> отдельная настройка CORS не требуется.

### 4.2. Собрать веб-сборку

```bash
cd <путь-к-проекту>
flutter pub get
flutter build web --release
```

Результат появится в `build/web/` (папки `index.html`, `main.dart.js`, `assets/` и т.д.).

### 4.3. Разместить сборку в `pb_public`

PocketBase раздаёт файлы из каталога `pb_public/` по адресу `http://<IP>:8090/`.

```bash
# На сервере
cd /opt/mgkct
mkdir -p pb_public

# Скопируйте содержимое build/web/ в pb_public (через scp/USB):
#   scp -r build/web/* server:/opt/mgkct/pb_public/
```

Проверьте структуру:

```bash
ls -la /opt/mgkct/pb_public
# должны быть: index.html, main.dart.js, manifest.json, assets/, flutter_bootstrap.js ...
```

---

## 5. Запуск как сервис (автозапуск после перезагрузки)

Создайте systemd-сервис, чтобы PocketBase стартовал сам при включении ПК.

Создать файл `/etc/systemd/system/pocketbase.service`:

```ini
[Unit]
Description=PocketBase - Вычитка (колледж)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mgkct
ExecStart=/opt/mgkct/pocketbase serve --http=0.0.0.0:8090 --automigrate=false
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

> `--http=0.0.0.0:8090` — слушать все интерфейсы, чтобы было доступно по сети
> (не только с локального `127.0.0.1`).

Включить и запустить:

```bash
sudo systemctl daemon-reload
sudo systemctl enable pocketbase   # автозапуск при загрузке
sudo systemctl start pocketbase
sudo systemctl status pocketbase   # должно быть active (running)
```

Логи при необходимости:

```bash
journalctl -u pocketbase -f
```

---

## 6. Проверка из локальной сети

Со **своего компьютера** (не сервера) в браузере:

1. `http://<IP-сервера>:8090/` → должна открыться **веб-версия приложения** (Flutter).
2. `http://<IP-сервера>:8090/_/` → админка PocketBase (вход superuser’ом), если нужно
   управлять коллекциями.

Проверка API из терминала (с любой машины сети):

```bash
curl http://<IP-сервера>:8090/api/health
# ожидаем: {"message":"API is healthy.",...}
```

---

## 7. Первичные данные (засев)

Пока никакой UI для создания пользователей/назначений нет, начальные данные вносятся
через админку PocketBase (`/_/`) или скриптом.

Минимальный набор:

- В коллекции **users** — по записи на каждого (email, password). Поле `display_name`.
- В коллекции **user_profiles** — связь с `user`, `role` (`teacher`/`admin`),
  `display_name`, `email`.
- В коллекции **assignments** — `teacher` (ссылка на профиль), `subject`, `group`, `year`.

> Схема уже создана миграцией (шаг 3.3), так что «Создать коллекцию» не нужно —
> только добавить записи.

См. также `/tmp/opencode/seed.sh` на рабочей машине — его можно адаптировать под продакшен.

---

## 8. Безопасность (внутренняя сеть — минимально)

Проект рассчитан на доверенную внутреннюю сеть колледжа (пароли в `users`
 хранятся открыто — по спецификации). Рекомендуется дополнительно:

- Открывать порт `8090` **только внутри** локальной сети (не на роутере/NAT наружу).
- Ограничить доступ к каталогу `pb_data/` (`chmod 700`), он содержит базу и ключи.
- Не коммитить `pb_data/`, `pb_public/`, бинарник и `service_account.json` (в `.gitignore` они уже есть).
- Периодически бэкапить `pb_data/data.db` (см. ниже).

---

## 9. Резервное копирование (важно!)

База — файл `PocketBase`:

```bash
# Остановить запись (опционально, но безопаснее)
sudo systemctl stop pocketbase
sudo cp /opt/mgkct/pb_data/data.db /backup/mgkct_$(date +%F).db
sudo systemctl start pocketbase
```

Проще всего — cron-задание (например, ежедневно в 03:00):

```bash
sudo crontab -e
# добавить строку:
0 3 * * * cp /opt/mgkct/pb_data/data.db /backup/mgkct_$(date +\%F).db
```

---

## 10. Обновление/изменение схемы в будущем

- Изменения схемы делайте **новыми** файлами миграций в `pb_migrations/`
  (не правьте применённый `1756000000000_init_collections.js`).
- Применение: `sudo systemctl stop pocketbase && cd /opt/mgkct && ./pocketbase migrate up --automigrate=false && sudo systemctl start pocketbase`.
- Правки кода Flutter → пересобрать web (шаг 4.2) и заменить `pb_public/`.
