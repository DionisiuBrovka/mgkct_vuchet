"""Black-box tests for the superuser-only atomic report storage primitive."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
PB = ROOT / "pocketbase"


class ReportStorageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mgkct-storage-")
        self.directory = Path(self.temp.name)
        migrated = subprocess.run(
            [str(PB), "migrate", "up", f"--dir={self.directory / 'data'}",
             f"--migrationsDir={ROOT / 'pb_migrations'}", "--automigrate=false"],
            input="y\n", text=True, capture_output=True, timeout=30)
        self.assertEqual(migrated.returncode, 0, migrated.stdout + migrated.stderr)
        password = "A-storage-test-password-1!"
        created = subprocess.run(
            [str(PB), "superuser", "upsert", "storage-test@example.invalid", password,
             f"--dir={self.directory / 'data'}"], text=True, capture_output=True, timeout=30)
        self.assertEqual(created.returncode, 0, created.stdout + created.stderr)
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0)); self.port = sock.getsockname()[1]
        self.process = subprocess.Popen(
            [str(PB), "serve", f"--dir={self.directory / 'data'}",
             f"--migrationsDir={ROOT / 'pb_migrations'}", f"--hooksDir={ROOT / 'pb_hooks'}",
             f"--http=127.0.0.1:{self.port}"], stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE, text=True)
        self.wait_for_server()
        _, auth = self.request("POST", "/api/collections/_superusers/auth-with-password",
                               {"identity": "storage-test@example.invalid", "password": password})
        self.token = auth["token"]
        self.teacher = self.create("users", {"email": "teacher@example.invalid", "password": password,
                                              "passwordConfirm": password, "name": "Тестовый преподаватель",
                                              "role": "teacher", "is_active": True, "auth_version": 1})["id"]
        subject = self.create("subjects", {"name": "Математика", "normalized_name": "математика"})["id"]
        group = self.create("groups", {"name": "ИВТ-1", "normalized_name": "ивт-1"})["id"]
        self.assignment = self.create("assignments", {"teacher": self.teacher, "subject": subject,
                                                        "group": group, "academic_year": 2026})["id"]

    def tearDown(self):
        if hasattr(self, "process"):
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill(); self.process.wait(timeout=10)
            self.process.stderr.close()
        self.temp.cleanup()

    def wait_for_server(self):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            try:
                status, _ = self.request("GET", "/api/health")
                if status == 200:
                    return
            except URLError:
                pass
            time.sleep(.05)
        stderr = self.process.stderr.read() if self.process.poll() is not None else "server did not become ready"
        self.fail(stderr)

    def request(self, method, path, payload=None, token=None):
        data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode()
        headers = {"Content-Type": "application/json"} if data else {}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = Request(f"http://127.0.0.1:{self.port}{path}", data=data, headers=headers, method=method)
        try:
            with urlopen(request, timeout=10) as response:
                return response.status, json.loads(response.read() or b"{}")
        except HTTPError as error:
            try:
                return error.code, json.loads(error.read() or b"{}")
            finally:
                error.close()

    def create(self, collection, payload):
        status, body = self.request("POST", f"/api/collections/{collection}/records", payload, self.token)
        self.assertEqual(status, 200, body)
        return body

    def records(self, collection, filter_text):
        status, body = self.request("GET", f"/api/collections/{collection}/records?filter={filter_text}", token=self.token)
        self.assertEqual(status, 200, body)
        return body["items"]

    def entry(self, entry_id=None, lecture="1.25"):
        return {"id": entry_id, "assignment": self.assignment, "lecture_hours": lecture,
                "practical_hours": "0", "course_project_hours": "0", "consultation_hours": "0",
                "additional_assessment_hours": "0", "exam_hours": "0"}

    def substitution(self, substitution_id=None, description="Замена", hours="2.5"):
        return {"id": substitution_id, "date": "2026-09-05", "description": description, "hours": hours}

    def command(self, revision, entries, substitutions):
        return self.request("POST", "/api/internal/report-write", {
            "teacher": self.teacher, "month": 9, "year": 2026, "status": "draft",
            "submitted_at": None, "confirmed_at": None, "confirmed_by": None,
            "expected_revision": revision, "entries": entries, "substitutions": substitutions,
        }, self.token)

    def test_cas_ownership_whitelist_and_rollback(self):
        unauthenticated, _ = self.request("POST", "/api/internal/report-write", {})
        self.assertIn(unauthenticated, (401, 403))

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.command(0, [self.entry()], [self.substitution()]), range(2)))
        self.assertEqual(sorted(status for status, _ in results), [200, 409])
        success = next(body for status, body in results if status == 200)
        report_id = success["id"]
        self.assertEqual(success["revision"], 1)
        reports = self.records("teaching_reports", f'id="{report_id}"')
        self.assertEqual([(row["revision"], row["status"]) for row in reports], [(1, "draft")])
        entries = self.records("teaching_report_entries", f'report="{report_id}"')
        substitutions = self.records("substitutions", f'report="{report_id}"')
        self.assertEqual(len(entries), 1); self.assertEqual(len(substitutions), 1)

        foreign_id = "x" * 15
        status, _ = self.command(1, [self.entry(foreign_id)], [self.substitution(substitutions[0]["id"])])
        self.assertEqual(status, 409)
        bad_body = {"teacher": self.teacher, "month": 9, "year": 2026, "status": "draft",
                    "submitted_at": None, "confirmed_at": None, "confirmed_by": None,
                    "expected_revision": 1, "entries": [self.entry(entries[0]["id"])],
                    "substitutions": [self.substitution(substitutions[0]["id"])] , "unexpected": True}
        status, _ = self.request("POST", "/api/internal/report-write", bad_body, self.token)
        self.assertEqual(status, 400)

        status, second_write = self.command(1, [self.entry(entries[0]["id"])], [
            self.substitution(substitutions[0]["id"]), self.substitution(None, "Вторая замена", "1")])
        self.assertEqual(status, 200)
        two_substitutions = self.records("substitutions", f'report="{report_id}"')
        self.assertEqual(len(two_substitutions), 2)
        kept = next(row for row in two_substitutions if row["description"] == "Вторая замена")
        status, third_write = self.command(second_write["revision"], [self.entry(entries[0]["id"])], [
            self.substitution(kept["id"], kept["description"], kept["hours"])])
        self.assertEqual(status, 200)
        self.assertEqual([(row["id"], row["description"]) for row in self.records("substitutions", f'report="{report_id}"')], [(kept["id"], "Вторая замена")])

        before_report = self.records("teaching_reports", f'id="{report_id}"')[0]
        before_entry = self.records("teaching_report_entries", f'report="{report_id}"')[0]
        before_substitution = self.records("substitutions", f'report="{report_id}"')[0]
        before = (before_report["revision"], before_report["status"], before_entry["lecture_hours"], before_substitution["description"], before_substitution["hours"])
        status, _ = self.command(third_write["revision"], [self.entry(entries[0]["id"], "3.75")], [
            self.substitution(kept["id"], "Изменённая", "4"),
            self.substitution(None, "Неверная дробь", "1e2")])
        self.assertGreaterEqual(status, 400)
        after_report = self.records("teaching_reports", f'id="{report_id}"')[0]
        after_entry = self.records("teaching_report_entries", f'report="{report_id}"')[0]
        after_substitutions = self.records("substitutions", f'report="{report_id}"')
        self.assertEqual((after_report["revision"], after_report["status"], after_entry["lecture_hours"], after_substitutions[0]["description"], after_substitutions[0]["hours"]), before)
        self.assertEqual(len(after_substitutions), 1)


if __name__ == "__main__":
    unittest.main()
