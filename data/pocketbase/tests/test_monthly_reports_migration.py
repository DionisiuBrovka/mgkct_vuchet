"""Backfill and failure atomicity for the monthly report schema."""
import unittest
import test_english_names_migration as legacy

MONTHLY = '1788134400000_monthly_reports.js'

class MonthlyReportsMigrationTest(unittest.TestCase):
    def fixture(self, valid=True):
        fixture = legacy.EnglishNamesMigrationTest()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        seed = legacy.SEED
        if valid:
            seed = seed.replace('["draft", "submitted", "confirmed"]', '["submitted"]')
        (fixture.migrations / '1756000000001_test_data.js').write_text(seed)
        fixture.copy_migration(legacy.RENAME)
        fixture.migrate('up')
        return fixture

    def test_backfills_relations_preserves_records_and_closes_rules(self):
        fixture = self.fixture()
        before = fixture.snapshot()
        fixture.copy_migration(MONTHLY)
        fixture.migrate('up')
        after = fixture.snapshot()
        report = after['teaching_reports'][1][0]
        self.assertEqual(report['status'], 'submitted')
        self.assertEqual(report['revision'], 1)
        for name in ['teaching_report_entries', 'substitutions']:
            records = after[name][1]
            self.assertTrue(all(row['report'] == report['id'] for row in records))
            self.assertEqual([{k: v for k, v in row.items() if k != 'report'} for row in records], before[name][1])
        for name in ['users', 'user_profiles', 'assignments', 'teaching_report_entries', 'substitutions', 'teaching_reports']:
            for rule in ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule']:
                self.assertIsNone(after[name][0][rule])
        fixture.migrate('up')
        self.assertEqual(fixture.snapshot(), after)

    def test_inconsistent_existing_reports_fail_without_data_loss(self):
        fixture = self.fixture(valid=False)
        before = fixture.snapshot()
        fixture.copy_migration(MONTHLY)
        fixture.migrate('up', success=False)
        self.assertEqual(fixture.snapshot(), before)

if __name__ == '__main__':
    unittest.main()
