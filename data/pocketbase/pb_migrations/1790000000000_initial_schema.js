// Clean baseline only: do not apply to a legacy data directory.
migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  users.fields.getByName("name").required = true
  users.fields.getByName("name").presentable = true
  users.fields.add(new SelectField({name: "role", required: true, maxSelect: 1, values: ["teacher", "admin"]}))
  // PocketBase treats a required false boolean as blank, so the create hook
  // supplies the true default while administrators remain able to block users.
  users.fields.add(new BoolField({name: "is_active"}))
  users.fields.add(new NumberField({name: "auth_version", required: true, onlyInt: true, min: 1}))
  for (const rule of ["listRule", "viewRule", "createRule", "updateRule", "deleteRule", "manageRule"]) users[rule] = null
  app.save(users)

  function base(name) {
    return new Collection({name, type: "base", listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null})
  }
  function named(name, index) {
    const c = base(name)
    c.fields.add(new TextField({name: "name", required: true, max: 200}))
    c.fields.add(new TextField({name: "normalized_name", required: true, max: 200}))
    c.addIndex(index, true, "normalized_name", "")
    app.save(c)
    return c
  }
  const subjects = named("subjects", "uq_subject_normalized_name")
  const groups = named("groups", "uq_group_normalized_name")
  const assignments = base("assignments")
  assignments.fields.add(new RelationField({name: "teacher", required: true, maxSelect: 1, collectionId: users.id, cascadeDelete: false}))
  assignments.fields.add(new RelationField({name: "subject", required: true, maxSelect: 1, collectionId: subjects.id, cascadeDelete: false}))
  assignments.fields.add(new RelationField({name: "group", required: true, maxSelect: 1, collectionId: groups.id, cascadeDelete: false}))
  assignments.fields.add(new NumberField({name: "academic_year", required: true, onlyInt: true, min: 2000, max: 2100}))
  assignments.addIndex("uq_assignment", true, "teacher, subject, group, academic_year", "")
  app.save(assignments)

  const reports = base("teaching_reports")
  reports.fields.add(new RelationField({name: "teacher", required: true, maxSelect: 1, collectionId: users.id, cascadeDelete: false}))
  reports.fields.add(new NumberField({name: "month", required: true, onlyInt: true, min: 1, max: 12}))
  reports.fields.add(new NumberField({name: "year", required: true, onlyInt: true, min: 2000, max: 2100}))
  reports.fields.add(new SelectField({name: "status", required: true, maxSelect: 1, values: ["draft", "submitted", "confirmed"]}))
  reports.fields.add(new NumberField({name: "revision", required: true, onlyInt: true, min: 1}))
  reports.fields.add(new DateField({name: "submitted_at"}))
  reports.fields.add(new DateField({name: "confirmed_at"}))
  reports.fields.add(new RelationField({name: "confirmed_by", maxSelect: 1, collectionId: users.id, cascadeDelete: false}))
  reports.addIndex("uq_report_period", true, "teacher, month, year", "")
  app.save(reports)

  const decimal = () => new TextField({name: "", required: true, min: 1, max: 1048576, pattern: "^(0|[1-9][0-9]*(\\.[0-9]*[1-9])?)$"})
  const entries = base("teaching_report_entries")
  entries.fields.add(new RelationField({name: "report", required: true, maxSelect: 1, collectionId: reports.id, cascadeDelete: false}))
  entries.fields.add(new RelationField({name: "assignment", required: true, maxSelect: 1, collectionId: assignments.id, cascadeDelete: false}))
  for (const name of ["lecture_hours", "practical_hours", "course_project_hours", "consultation_hours", "additional_assessment_hours", "exam_hours"]) { const f = decimal(); f.name = name; entries.fields.add(f) }
  entries.addIndex("uq_report_assignment", true, "report, assignment", "")
  app.save(entries)

  const substitutions = base("substitutions")
  substitutions.fields.add(new RelationField({name: "report", required: true, maxSelect: 1, collectionId: reports.id, cascadeDelete: false}))
  substitutions.fields.add(new TextField({name: "date", required: true, min: 10, max: 10, pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"}))
  substitutions.fields.add(new TextField({name: "description", required: true, min: 1, max: 500}))
  const hours = decimal(); hours.name = "hours"; substitutions.fields.add(hours)
  app.save(substitutions)

  const sessions = base("app_sessions")
  sessions.fields.add(new RelationField({name: "user", required: true, maxSelect: 1, collectionId: users.id, cascadeDelete: false}))
  sessions.fields.add(new TextField({name: "token_hash", required: true, min: 64, max: 64, pattern: "^[a-f0-9]{64}$"}))
  sessions.fields.add(new NumberField({name: "auth_version", required: true, onlyInt: true, min: 1}))
  sessions.fields.add(new DateField({name: "created_at", required: true}))
  sessions.fields.add(new DateField({name: "last_seen_at", required: true}))
  sessions.fields.add(new DateField({name: "expires_at", required: true}))
  sessions.fields.add(new DateField({name: "revoked_at"}))
  sessions.addIndex("uq_session_token_hash", true, "token_hash", "")
  sessions.addIndex("idx_session_user", false, "user", "")
  sessions.addIndex("idx_session_expiry", false, "expires_at", "")
  sessions.addIndex("idx_session_revoked", false, "revoked_at", "")
  app.save(sessions)
}, () => {
  for (const name of ["app_sessions", "substitutions", "teaching_report_entries", "teaching_reports", "assignments", "groups", "subjects"]) {
    try { app.delete(app.findCollectionByNameOrId(name)) } catch (_) {}
  }
  const users = app.findCollectionByNameOrId("users")
  for (const name of ["role", "is_active", "auth_version"]) { try { users.fields.removeByName(name) } catch (_) {} }
  app.save(users)
})
