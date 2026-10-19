migrate((app) => {
  const triggers = [
    `CREATE TRIGGER protect_used_assignment_update BEFORE UPDATE ON assignments
     WHEN (OLD.teacher != NEW.teacher OR OLD.subject != NEW.subject OR OLD."group" != NEW."group" OR OLD.academic_year != NEW.academic_year)
       AND EXISTS (SELECT 1 FROM teaching_report_entries WHERE assignment = OLD.id)
     BEGIN SELECT RAISE(ABORT, 'Used assignment is immutable'); END`,
    `CREATE TRIGGER protect_used_assignment_delete BEFORE DELETE ON assignments
     WHEN EXISTS (SELECT 1 FROM teaching_report_entries WHERE assignment = OLD.id)
     BEGIN SELECT RAISE(ABORT, 'Used assignment cannot be deleted'); END`,
    `CREATE TRIGGER protect_used_subject_update BEFORE UPDATE ON subjects
     WHEN (OLD.name != NEW.name OR OLD.normalized_name != NEW.normalized_name)
       AND EXISTS (SELECT 1 FROM assignments WHERE subject = OLD.id)
     BEGIN SELECT RAISE(ABORT, 'Used subject is immutable'); END`,
    `CREATE TRIGGER protect_used_group_update BEFORE UPDATE ON "groups"
     WHEN (OLD.name != NEW.name OR OLD.normalized_name != NEW.normalized_name)
       AND EXISTS (SELECT 1 FROM assignments WHERE "group" = OLD.id)
     BEGIN SELECT RAISE(ABORT, 'Used group is immutable'); END`,
    `CREATE TRIGGER protect_used_subject_delete BEFORE DELETE ON subjects
     WHEN EXISTS (SELECT 1 FROM assignments WHERE subject = OLD.id)
     BEGIN SELECT RAISE(ABORT, 'Used subject cannot be deleted'); END`,
    `CREATE TRIGGER protect_used_group_delete BEFORE DELETE ON "groups"
     WHEN EXISTS (SELECT 1 FROM assignments WHERE "group" = OLD.id)
     BEGIN SELECT RAISE(ABORT, 'Used group cannot be deleted'); END`,
  ]
  for (const sql of triggers) app.db().newQuery(sql).execute()
}, (app) => {
  for (const name of ["protect_used_assignment_update", "protect_used_assignment_delete", "protect_used_subject_update", "protect_used_group_update", "protect_used_subject_delete", "protect_used_group_delete"])
    app.db().newQuery("DROP TRIGGER IF EXISTS " + name).execute()
})
