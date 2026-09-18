# CI QA

Task 26 добавляет `.github/workflows/check.yml` для GitHub Actions: checkout,
фиксированные Dart/Flutter, проверка PocketBase SHA/version, затем единственный
`bash scripts/check.sh`. После успешного master-check workflow собирает server
binary и публикует Web+server artifact с именем, содержащим SHA commit.

Локально 2026-09-18 `bash scripts/check.sh` завершился exit 0. Первый remote
run `35321331278` на `b1c0101` честно выявил отсутствие ignored PocketBase
binary в чистом checkout. Исправление добавляет `scripts/fetch-pocketbase.sh`:
оно скачивает PocketBase 0.40.1 только после SHA-256 проверки; CI и локальный
master-check используют тот же bootstrap. Повторный remote run и скачивание
artifact должны проверяться уже на commit с этим исправлением. Workflow не
содержит deploy или secrets.
