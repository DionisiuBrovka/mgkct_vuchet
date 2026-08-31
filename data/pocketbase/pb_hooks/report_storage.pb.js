// Storage primitive only. Shelf owns authorization, validation and workflow rules.
// A compare-and-swap transaction protects against stale clients and server replicas.
routerAdd("POST", "/api/internal/report-write", (event) => {
  const body = event.requestInfo().body
  let result
  $app.runInTransaction((app) => {
    const rows = app.findRecordsByFilter("teaching_reports",
      "teacher = {:teacher} && month = {:month} && year = {:year}", "", 1, 0,
      {teacher: body.teacher, month: body.month, year: body.year})
    const report = rows.length ? rows[0] : new Record(app.findCollectionByNameOrId("teaching_reports"))
    const revision = rows.length ? report.getInt("revision") : 0
    if (revision !== body.expected_revision) throw new ApiError(409, "Report revision conflict")
    for (const field of ["teacher", "month", "year", "status", "submitted_at", "confirmed_at", "confirmed_by"]) {
      report.set(field, body[field] || "")
    }
    report.set("revision", revision + 1)
    app.save(report)
    for (const name of ["teaching_report_entries", "substitutions"]) {
      const current = app.findRecordsByFilter(name, "report = {:id}", "", 0, 0, {id: report.id})
      const currentById = {}
      for (const child of current) currentById[child.id] = child
      const keep = new Set()
      const values = name === "teaching_report_entries" ? body.entries : body.substitutions
      for (const value of values) {
        const child = value.id ? currentById[value.id] : new Record(app.findCollectionByNameOrId(name))
        if (!child) throw new ApiError(409, "Record does not belong to this report")
        if (value.id && keep.has(value.id)) throw new ApiError(400, "Duplicate record")
        for (const field in value) if (field !== "id") child.set(field, value[field])
        child.set("report", report.id)
        child.set("month", body.month)
        child.set("year", body.year)
        if (name === "substitutions") child.set("teacher", body.teacher)
        else {
          for (const field of ["status", "submitted_at", "confirmed_at", "confirmed_by"]) child.set(field, report.get(field))
        }
        app.save(child)
        keep.add(child.id)
      }
      for (const child of current) if (!keep.has(child.id)) app.delete(child)
    }
    result = {id: report.id, revision: report.getInt("revision")}
  })
  return event.json(200, result)
}, $apis.requireSuperuserAuth())
