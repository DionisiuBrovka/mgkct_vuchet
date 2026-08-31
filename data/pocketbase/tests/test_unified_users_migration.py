"""Account merge: preserve credentials, report history and transactional failure."""
import unittest
import test_english_names_migration as legacy
from test_monthly_reports_migration import MONTHLY

UNIFIED = '1788220800000_unified_users.js'


class UnifiedUsersMigrationTest(unittest.TestCase):
    def fixture(self, change=''):
        fixture = legacy.EnglishNamesMigrationTest()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        # Different IDs and a separate admin catch missing or incorrect remapping.
        seed = legacy.SEED.replace('["draft", "submitted", "confirmed"]', '["confirmed"]')
        seed = seed.replace('  const assignment =', '''
  const adminUser = create("users", {
    email: "admin@example.com", password: "MigrationTest123!",
  })
  const admin = create("user_profiles", {
    user: adminUser, email: "admin@example.com", role: "admin", display_name: "Завуч",
  })
  const assignment =''').replace('? teacher :', '? admin :')
        seed = seed.replace('}, () => {})', change + '\n}, () => {})')
        (fixture.migrations / '1756000000001_test_data.js').write_text(seed)
        fixture.copy_migration(legacy.RENAME)
        fixture.copy_migration(MONTHLY)
        fixture.migrate('up')
        return fixture

    def test_merge_preserves_credentials_history_and_all_relations(self):
        fixture = self.fixture()
        before = fixture.snapshot()
        mapping = {p['id']: p['user'] for p in before['user_profiles'][1]}
        profiles = {p['user']: p for p in before['user_profiles'][1]}
        fixture.copy_migration(UNIFIED)
        fixture.migrate('up')
        after = fixture.snapshot()
        self.assertNotIn('user_profiles', after)
        for old, new in zip(before['users'][1], after['users'][1]):
            self.assertEqual(new['role'], profiles[old['id']]['role'])
            self.assertEqual(new['display_name'], profiles[old['id']]['display_name'])
            for key in old:
                if key not in {'display_name', 'updated'}:
                    self.assertEqual(new[key], old[key], key)
        users_id = after['users'][0]['id']
        profile_id = before['user_profiles'][0]['id']
        for name in ['assignments', 'teaching_reports', 'teaching_report_entries', 'substitutions']:
            fields = [f['name'] for f in before[name][0]['fields']
                      if f.get('collectionId') == profile_id]
            expected = [{k: mapping.get(v, v) if k in fields else v
                         for k, v in row.items()} for row in before[name][1]]
            self.assertEqual(after[name][1], expected)
            for field in after[name][0]['fields']:
                if field['name'] in fields:
                    self.assertEqual(field['collectionId'], users_id)
        for rule in ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule']:
            self.assertIsNone(after['users'][0][rule])
        fixture.migrate('up')
        self.assertEqual(fixture.snapshot(), after)

    def test_conflicting_email_name_and_missing_profile_fail_without_changes(self):
        for change in [
            'const u = app.findRecordById("users", user); u.set("email", "different@example.com"); app.save(u)',
            'const u = app.findRecordById("users", user); u.set("display_name", "Другое имя"); app.save(u)',
            'create("users", {email: "orphan@example.com", password: "MigrationTest123!"})',
        ]:
            with self.subTest(change=change):
                fixture = self.fixture(change)
                before = fixture.snapshot()
                fixture.copy_migration(UNIFIED)
                fixture.migrate('up', success=False)
                self.assertEqual(fixture.snapshot(), before)

    def test_late_failure_restores_profiles_accounts_and_relations(self):
        fixture = self.fixture()
        before = fixture.snapshot()
        source = (legacy.BACKEND / 'pb_migrations' / UNIFIED).read_text()
        source = source.replace('  app.delete(profiles)',
                                '  app.delete(profiles)\n  throw new Error("test rollback")')
        (fixture.migrations / UNIFIED).write_text(source)
        fixture.migrate('up', success=False)
        self.assertEqual(fixture.snapshot(), before)


if __name__ == '__main__':
    unittest.main()
