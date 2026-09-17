// Superuser-only storage primitive; Shelf validates rights, workflow and totals.
routerAdd("POST", "/api/internal/report-write", (event) => {
  const body = event.requestInfo().body
  const decimalFields = ["lecture_hours", "practical_hours", "course_project_hours", "consultation_hours", "additional_assessment_hours", "exam_hours"]
  const hasOnly = (value, fields) => value && typeof value === "object" && !Array.isArray(value) && Object.keys(value).every((key) => fields.includes(key))
  const commandFields = ["teacher", "month", "year", "status", "submitted_at", "confirmed_at", "confirmed_by", "expected_revision", "entries", "substitutions"]
  if (!hasOnly(body, commandFields) || typeof body.teacher !== "string" || !Number.isInteger(body.month) || !Number.isInteger(body.year) || !Number.isInteger(body.expected_revision) || !Array.isArray(body.entries) || !Array.isArray(body.substitutions)) throw new ApiError(400, "Invalid storage command")
  let result
  $app.runInTransaction((app) => {
    const reports = app.findRecordsByFilter("teaching_reports", "teacher = {:teacher} && month = {:month} && year = {:year}", "", 2, 0, {teacher: body.teacher, month: body.month, year: body.year})
    if (reports.length > 1) throw new ApiError(409, "Duplicate report period")
    const report = reports.length ? reports[0] : new Record(app.findCollectionByNameOrId("teaching_reports"))
    const revision = reports.length ? report.getInt("revision") : 0
    if (revision !== body.expected_revision) throw new ApiError(409, "Report revision conflict")
    report.set("teacher", body.teacher); report.set("month", body.month); report.set("year", body.year)
    report.set("status", body.status); report.set("submitted_at", body.submitted_at || ""); report.set("confirmed_at", body.confirmed_at || ""); report.set("confirmed_by", body.confirmed_by || "")
    report.set("revision", revision + 1); app.save(report)
    const writeChildren = (collection, values, fields) => {
      const existing = app.findRecordsByFilter(collection, "report = {:report}", "", 0, 0, {report: report.id})
      const byId = {}; for (const row of existing) byId[row.id] = row
      const keep = new Set()
      const naturalKeys = new Set()
      for (const value of values) {
        if (!hasOnly(value, ["id", ...fields]) || !("id" in value) || (value.id !== null && typeof value.id !== "string")) throw new ApiError(400, "Invalid child command")
        if (value.id && (keep.has(value.id) || !byId[value.id])) throw new ApiError(409, "Invalid child ownership")
        // A report has one row per assignment; substitutions intentionally may share a date.
        if (collection === "teaching_report_entries") {
          if (typeof value.assignment !== "string" || naturalKeys.has(value.assignment)) throw new ApiError(409, "Duplicate report assignment")
          naturalKeys.add(value.assignment)
        }
        const row = value.id ? byId[value.id] : new Record(app.findCollectionByNameOrId(collection))
        for (const field of fields) { if (!(field in value)) throw new ApiError(400, "Missing child field"); row.set(field, value[field]) }
        row.set("report", report.id); app.save(row); keep.add(row.id)
      }
      for (const row of existing) if (!keep.has(row.id)) app.delete(row)
    }
    writeChildren("teaching_report_entries", body.entries, ["assignment", ...decimalFields])
    writeChildren("substitutions", body.substitutions, ["date", "description", "hours"])
    result = {id: report.id, revision: revision + 1}
  })
  return event.json(200, result)
}, $apis.requireSuperuserAuth())
