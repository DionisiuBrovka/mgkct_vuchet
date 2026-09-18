# Вычитка

Web-приложение учёта учебной нагрузки. Преподаватель заполняет месячный отчёт
и отправляет его; завуч проверяет, возвращает или подтверждает. Интерфейс
русский, технические имена английские.

## Состав

`client/` — Flutter Web; `server/` — Shelf API и правила; `data/pocketbase/`
— PB 0.40.1, схема и storage hooks. Браузер обращается только к Shelf: PocketBase
и service credentials ему недоступны.

Учебный год: сентябрь–июль; августа нет. Часы — точные decimal strings, а не
`double`. Статусы: `draft → submitted → confirmed`, возврат переводит
`submitted` обратно в `draft`; confirmed read-only. Сессия — HttpOnly cookie.

## Пользователи и данные

В закрытой PB admin UI создайте `users` с email, password, `name`, role
(`teacher` или `admin`), `is_active` и `auth_version`. Одинаковые ФИО допустимы:
на входе они различаются хвостом ID. Создайте subjects, groups и assignments;
`academic_year` — год начала учебного года. Не используйте рабочие учётные
записи в тестах.

## Проверка

```bash
bash scripts/check.sh
```

Скрипт не читает `.env` и использует временные данные. Он требует Dart, Flutter,
Python 3 и `data/pocketbase/pocketbase`. CI запускает эту же команду.

## Deploy (Linux x86_64, Podman)

```bash
cp .env.example .env
# замените PB_SERVICE_PASSWORD и PUBLIC_ORIGIN
bash scripts/deploy.sh up
bash scripts/deploy.sh status
bash scripts/deploy.sh logs
```

`down` останавливает контейнеры, но не удаляет volume `mgkct_data`. PB публикуется
только на localhost; Shelf/Web — на `APP_BIND:APP_PORT`. Для публичной сети нужен
явно настроенный HTTPS reverse proxy. Проверка без рабочей `.env`:

```bash
bash scripts/deploy.sh --self-test
```

Для локального PB без контейнеров обязательно задайте абсолютный `PB_DATA_DIR`;
скрипты не выбирают и не мигрируют старые базы автоматически.

## Ограничения

Нет экспорта, комментариев, массового подтверждения, клиентского администрирования
и офлайн-синхронизации. Полные контракты и QA-протоколы находятся в `task/`.
