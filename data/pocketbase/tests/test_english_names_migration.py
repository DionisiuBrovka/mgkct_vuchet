"""Migration regression checks; uses only temporary databases and the local binary.

Run: python3 -m unittest discover -s data/pocketbase/tests -v
Legacy identifiers below are intentional fixtures for the previous schema.
"""

import json
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import unittest


BACKEND = Path(__file__).resolve().parents[1]
INITIAL = "1756000000000_init_collections.js"
RENAME = "1788048000000_english_names.js"
COLLECTION_NAMES = {"vychitki": "teaching_report_entries", "zameny": "substitutions"}
FIELD_NAMES = {
    "lek": "lecture_hours",
    "lrPr": "practical_hours",
    "kp": "course_project_hours",
    "cons": "consultation_hours",
    "dopKontr": "additional_assessment_hours",
    "ekz": "exam_hours",
}

SEED = r'''
migrate((app) => {
  function create(collection, values) {
    const record = new Record(app.findCollectionByNameOrId(collection))
    for (const key in values) record.set(key, values[key])
    app.save(record)
    return record.id
  }
  const user = create("users", {
    email: "migration@example.com", password: "MigrationTest123!",
  })
  const teacher = create("user_profiles", {
    user, email: "migration@example.com", role: "teacher", display_name: "Тестовый преподаватель",
  })
  const assignment = create("assignments", {
    teacher, subject: "Математика", group: "ПР-21", year: 2026,
  })
  for (const status of ["draft", "submitted", "confirmed"]) {
    create("vychitki", {
      assignment, month: "Сентябрь", year: 2026, status,
      lek: 2.5, lrPr: 4.25, kp: 0, cons: 1.5, dopKontr: 3, ekz: 6,
      submitted_at: status === "draft" ? "" : "2026-09-30 12:00:00.000Z",
      confirmed_at: status === "confirmed" ? "2026-10-01 12:00:00.000Z" : "",
      confirmed_by: status === "confirmed" ? teacher : "",
    })
  }
  create("zameny", {
    teacher, month: "Сентябрь", year: 2026, group: "ПР-22",
    date: "15.09.2026", hours: 1.5,
  })
}, () => {})
'''


class EnglishNamesMigrationTest(unittest.TestCase):
    def setUp(self):
        if not (BACKEND / "pocketbase").is_file():
            self.fail("Install the PocketBase binary at data/pocketbase/pocketbase")
        self.temp = tempfile.TemporaryDirectory(prefix="teaching-hours-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.migrations = self.root / "migrations"
        self.migrations.mkdir()
        self.copy_migration(INITIAL)

    def copy_migration(self, name):
        shutil.copy2(BACKEND / "pb_migrations" / name, self.migrations / name)

    def migrate(self, *args, success=True):
        result = subprocess.run(
            [str(BACKEND / "pocketbase"), "migrate", *args,
             "--dir=" + str(self.root / "data"),
             "--migrationsDir=" + str(self.migrations), "--automigrate=false"],
            input="y\n", capture_output=True, text=True, timeout=30,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)

    def seed_legacy(self):
        (self.migrations / "1756000000001_test_data.js").write_text(SEED)
        self.migrate("up")

    def snapshot(self, normalize=False):
        connection = sqlite3.connect(self.root / "data" / "data.db")
        connection.row_factory = sqlite3.Row
        try:
            result = {}
            for collection in connection.execute(
                "SELECT * FROM _collections WHERE name NOT GLOB '_*'"
            ):
                collection = dict(collection)
                name = collection["name"]
                quoted_name = '"' + name.replace('"', '""') + '"'
                records = [dict(row) for row in connection.execute(
                    f"SELECT * FROM {quoted_name} ORDER BY id"
                )]
                fields = json.loads(collection["fields"])
                if normalize:
                    collection["name"] = COLLECTION_NAMES.get(name, name)
                    if name == "vychitki":
                        for field in fields:
                            field["name"] = FIELD_NAMES.get(field["name"], field["name"])
                        records = [{FIELD_NAMES.get(key, key): value
                                    for key, value in row.items()} for row in records]
                collection["fields"] = fields
                # PocketBase updates schema metadata timestamps on save.
                collection.pop("updated", None)
                result[collection["name"]] = (collection, records)
            return result
        finally:
            connection.close()

    def test_fresh_database(self):
        self.copy_migration(RENAME)
        self.migrate("up")
        snapshot = self.snapshot()
        self.assertIn("teaching_report_entries", snapshot)
        self.assertIn("substitutions", snapshot)
        self.assertNotIn("vychitki", snapshot)
        self.assertNotIn("zameny", snapshot)
        fields = {field["name"] for field in snapshot["teaching_report_entries"][0]["fields"]}
        self.assertTrue(set(FIELD_NAMES.values()) <= fields)
        self.assertFalse(set(FIELD_NAMES) & fields)

    def test_preserves_records_ids_relations_rules_and_round_trip(self):
        self.seed_legacy()
        original = self.snapshot()
        expected = self.snapshot(normalize=True)
        self.copy_migration(RENAME)
        self.migrate("up")
        self.assertEqual(self.snapshot(), expected)
        self.migrate("up")  # Repeated startup must be harmless.
        self.assertEqual(self.snapshot(), expected)
        self.migrate("down", "1")
        self.assertEqual(self.snapshot(), original)
        self.migrate("up")
        self.assertEqual(self.snapshot(), expected)

    def test_failure_rolls_back_both_collection_renames(self):
        self.seed_legacy()
        expected = self.snapshot()
        # Inject a failure after both saves; no partial rename may remain.
        source = (BACKEND / "pb_migrations" / RENAME).read_text()
        source = source.replace("    app.save(substitutions)",
                                '    app.save(substitutions)\n    throw new Error("test failure")', 1)
        (self.migrations / RENAME).write_text(source)
        self.migrate("up", success=False)
        self.assertEqual(self.snapshot(), expected)


if __name__ == "__main__":
    unittest.main()
