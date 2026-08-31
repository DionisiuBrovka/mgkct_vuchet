// Introduce a versioned aggregate without deleting any existing workload records.
migrate((app) => {
  const profiles = app.findCollectionByNameOrId("user_profiles")
  const reports = new Collection({
    name: "teaching_reports", type: "base",
    listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null,
  })
  for (const field of [
      new RelationField({name: "teacher", collectionId: profiles.id, maxSelect: 1, required: true}),
      new TextField({name: "month", required: true}),
      new NumberField({name: "year", required: true, onlyInt: true}),
      new SelectField({name: "status", required: true, maxSelect: 1, values: ["draft", "submitted", "confirmed"]}),
      new NumberField({name: "revision", required: true, min: 1, onlyInt: true}),
      new DateField({name: "submitted_at"}),
      new DateField({name: "confirmed_at"}),
      new RelationField({name: "confirmed_by", collectionId: profiles.id, maxSelect: 1}),
  ]) reports.fields.add(field)
  reports.addIndex("idx_report_period", true, "teacher, month, year", "")
  app.save(reports)
  const groups = {}
  function group(teacher, month, year) {
    const key = JSON.stringify([teacher, month, year])
    if (!groups[key]) groups[key] = {teacher, month, year, entries: [], substitutions: []}
    return groups[key]
  }
  const entries = app.findAllRecords("teaching_report_entries")
  for (const entry of entries) {
    const assignment = app.findRecordById("assignments", entry.getString("assignment"))
    group(assignment.getString("teacher"), entry.getString("month"), entry.getInt("year")).entries.push(entry)
  }
  for (const substitution of app.findAllRecords("substitutions")) {
    group(substitution.getString("teacher"), substitution.getString("month"), substitution.getInt("year")).substitutions.push(substitution)
  }
  for (const name of ["teaching_report_entries", "substitutions"]) {
    const collection = app.findCollectionByNameOrId(name)
    collection.fields.add(new RelationField({name: "report", collectionId: reports.id, maxSelect: 1}))
    app.save(collection)
  }
  for (const key in groups) {
    const value = groups[key]
    const statuses = [...new Set(value.entries.map(r => r.getString("status")))]
    const assignments = value.entries.map(r => r.getString("assignment"))
    if (statuses.length > 1 || new Set(assignments).size !== assignments.length) {
      throw new Error("Resolve mixed statuses or duplicate assignments before migration: " + key)
    }
    const record = new Record(reports)
    for (const field of ["teacher", "month", "year"]) record.set(field, value[field])
    record.set("status", statuses[0] || "draft")
    record.set("revision", 1)
    for (const field of ["submitted_at", "confirmed_at", "confirmed_by"]) {
      const values = value.entries.map(r => r.getString(field)).filter(v => v).sort()
      record.set(field, values.length ? values[values.length - 1] : "")
    }
    app.save(record)
    for (const [name, children] of [["teaching_report_entries", value.entries], ["substitutions", value.substitutions]]) {
      for (const child of children) {
        // Reload against the updated schema; pre-migration records lack this field.
        const updated = app.findRecordById(name, child.id)
        updated.set("report", record.id)
        app.save(updated)
      }
    }
  }
  for (const name of ["teaching_report_entries", "substitutions"]) {
    const collection = app.findCollectionByNameOrId(name)
    collection.fields.getByName("report").required = true
    if (name === "teaching_report_entries") {
      collection.addIndex("idx_report_assignment", true, "report, assignment", "")
    }
    app.save(collection)
  }
  profiles.addIndex("idx_profile_account", true, "user", "")
  app.save(profiles)
  // All application data is available only to the server's service account.
  // Password authentication remains available; public account creation does not.
  for (const name of ["users", "user_profiles", "assignments", "teaching_report_entries", "substitutions"]) {
    const collection = app.findCollectionByNameOrId(name)
    for (const rule of ["listRule", "viewRule", "createRule", "updateRule", "deleteRule"]) collection[rule] = null
    app.save(collection)
  }
}, () => {
  throw new Error("Restore a full pre-upgrade backup to roll back the monthly report schema.")
})
