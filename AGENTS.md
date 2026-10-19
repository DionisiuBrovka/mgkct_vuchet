# Engineering guide

Web-only Flutter + Shelf + PocketBase project. Keep technical names English and
user-facing text Russian. Read `task/product_spec.md` and current task documents
before changing product behaviour.

- Client calls Shelf only; never expose PB collections, tokens or service credentials.
- Shelf owns validation, roles, status transitions, totals and revision conflicts.
- Do not edit an applied PB migration. New schema work uses disposable PB data.
- PocketBase admin may correct planned hours at any time. An assignment already
  used in a report keeps its teacher, subject, group and academic year; archive
  it with `is_archived` and create a replacement. Archived assignments remain in
  existing reports and statistics but are excluded from new reports.
- Do not rename or delete subjects or groups referenced by assignments, or delete
  assignments referenced by report entries. Keep these rules enforced in PB
  storage so direct admin edits cannot bypass them.
- Decimal values stay strings/BigInt-style exact values; do not introduce `double`.
- `confirmed` reports are immutable; header, entries and substitutions change atomically.
- Tests never use `.env`, production volumes, users or PB_DATA_DIR.
- Run `bash scripts/check.sh` for a full local gate. Deploy via `scripts/deploy.sh`;
  normal deploy never deletes persistent data.
- Generated files are committed only when imported; regenerate with
  `dart run build_runner build --delete-conflicting-outputs` from `client/`.
- Add comments only for non-obvious invariants or security boundaries.
