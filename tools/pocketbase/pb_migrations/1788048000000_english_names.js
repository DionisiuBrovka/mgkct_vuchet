// Rename collections and fields in place: preserve IDs, relations and values.
// PocketBase runs each migration callback in a transaction.
migrate(
  (app) => {
    const entries = app.findCollectionByNameOrId("vychitki")
    const fields = {
      lek: "lecture_hours",
      lrPr: "practical_hours",
      kp: "course_project_hours",
      cons: "consultation_hours",
      dopKontr: "additional_assessment_hours",
      ekz: "exam_hours",
    }
    for (const oldName in fields) {
      // Mutate the existing field: replacing it would lose its stable ID.
      entries.fields.getByName(oldName).name = fields[oldName]
    }
    entries.name = "teaching_report_entries"
    app.save(entries)

    const substitutions = app.findCollectionByNameOrId("zameny")
    substitutions.name = "substitutions"
    app.save(substitutions)
  },
  (app) => {
    const entries = app.findCollectionByNameOrId("teaching_report_entries")
    const fields = {
      lecture_hours: "lek",
      practical_hours: "lrPr",
      course_project_hours: "kp",
      consultation_hours: "cons",
      additional_assessment_hours: "dopKontr",
      exam_hours: "ekz",
    }
    for (const oldName in fields) {
      entries.fields.getByName(oldName).name = fields[oldName]
    }
    entries.name = "vychitki"
    app.save(entries)

    const substitutions = app.findCollectionByNameOrId("substitutions")
    substitutions.name = "zameny"
    app.save(substitutions)
  },
)
