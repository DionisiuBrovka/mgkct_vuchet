"""Clean PocketBase baseline schema; every database is temporary."""
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PB = ROOT / "pocketbase"


class InitialSchemaTest(unittest.TestCase):
    def migrate(self, directory):
        result = subprocess.run(
            [str(PB), "migrate", "up", f"--dir={directory / 'data'}",
             f"--migrationsDir={ROOT / 'pb_migrations'}", "--automigrate=false"],
            input="y\n", text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def schema(self, directory):
        db = sqlite3.connect(directory / "data" / "data.db")
        try:
            return {name: (json.loads(fields), json.loads(indexes), rules)
                    for name, fields, indexes, *rules in db.execute(
                        "SELECT name, fields, indexes, listRule, viewRule, createRule, updateRule, deleteRule "
                        "FROM _collections WHERE name NOT GLOB '_*'")}
        finally:
            db.close()

    def test_two_fresh_databases_have_same_clean_schema_and_repeat_is_noop(self):
        with tempfile.TemporaryDirectory(prefix="mgkct-schema-") as left, tempfile.TemporaryDirectory(prefix="mgkct-schema-") as right:
            left, right = Path(left), Path(right)
            self.migrate(left); self.migrate(right)
            before = self.schema(left)
            self.assertEqual(before, self.schema(right))
            self.migrate(left)
            self.assertEqual(before, self.schema(left))
        collections = set(before)
        self.assertEqual(collections, {"users", "subjects", "groups", "assignments", "teaching_reports", "teaching_report_entries", "substitutions", "app_sessions"})
        self.assertNotIn("user_profiles", collections)
        self.assertNotIn("display_name", {f["name"] for f in before["users"][0]})

    def test_fields_indexes_and_direct_access_match_contract(self):
        with tempfile.TemporaryDirectory(prefix="mgkct-schema-") as temp:
            self.migrate(Path(temp)); schema = self.schema(Path(temp))
        fields = {name: {f["name"]: f for f in value[0]} for name, value in schema.items()}
        self.assertEqual(set(fields["teaching_report_entries"]) - {"id"}, {"report", "assignment", "lecture_hours", "practical_hours", "course_project_hours", "consultation_hours", "additional_assessment_hours", "exam_hours"})
        self.assertEqual(set(fields["substitutions"]) - {"id"}, {"report", "date", "description", "hours"})
        for value in fields["teaching_report_entries"].values():
            if value["name"].endswith("hours"):
                self.assertEqual(value["type"], "text")
        expected_indexes = {"subjects": "uq_subject_normalized_name", "groups": "uq_group_normalized_name", "assignments": "uq_assignment", "teaching_reports": "uq_report_period", "teaching_report_entries": "uq_report_assignment", "app_sessions": "uq_session_token_hash"}
        for collection, index in expected_indexes.items():
            self.assertTrue(any(index in value for value in schema[collection][1]))
        for collection, value in schema.items():
            self.assertEqual(value[2], [None] * 5, collection)


if __name__ == "__main__":
    unittest.main()
