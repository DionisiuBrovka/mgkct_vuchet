# Engineering guide

Web-only Flutter + Shelf + PocketBase project. Keep technical names English and
user-facing text Russian. Read `task/product_spec.md` and current task documents
before changing product behaviour.

- Client calls Shelf only; never expose PB collections, tokens or service credentials.
- Shelf owns validation, roles, status transitions, totals and revision conflicts.
- Do not edit an applied PB migration. New schema work uses disposable PB data.
- Decimal values stay strings/BigInt-style exact values; do not introduce `double`.
- `confirmed` reports are immutable; header, entries and substitutions change atomically.
- Tests never use `.env`, production volumes, users or PB_DATA_DIR.
- Run `bash scripts/check.sh` for a full local gate. Deploy via `scripts/deploy.sh`;
  normal deploy never deletes its persistent volume.
- Generated files are committed only when imported; regenerate with
  `dart run build_runner build --delete-conflicting-outputs` from `client/`.
- Add comments only for non-obvious invariants or security boundaries.
