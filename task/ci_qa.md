# CI QA

Task 26 добавляет `.github/workflows/check.yml` для GitHub Actions: checkout,
фиксированные Dart/Flutter, проверка PocketBase SHA/version, затем единственный
`bash scripts/check.sh`. После успешного master-check workflow собирает server
binary и публикует Web+server artifact с именем, содержащим SHA commit.

Локально 2026-09-18 `bash scripts/check.sh` завершился exit 0. GitHub CLI
авторизован для `DionisiuBrovka/mgkct_vuchet`, но workflow не отправлялся в
remote в рамках этой задачи: реальный Actions run и скачивание artifact ещё не
проверены. Workflow не содержит deploy или secrets.
