// Storage invariants for direct PB administration. Shelf owns workflow.
function fail(message) { throw new BadRequestError(message) }
function normalized(value) {
  if (typeof value !== "string") fail("Name is required")
  const result = value.normalize("NFC").trim().replace(/\s+/gu, " ").toLowerCase()
  if (!result) fail("Name is required")
  return result
}
function used(app, collection, field, id) {
  return app.findRecordsByFilter(collection, field + " = {:id}", "", 1, 0, {id}).length > 0
}
onRecordValidate((e) => {
  e.record.set("normalized_name", normalized(e.record.getString("name")))
  e.next()
}, "subjects", "groups")
onRecordCreate((e) => {
  if (!e.record.get("is_active")) e.record.set("is_active", true)
  if (e.record.getInt("auth_version") < 1) e.record.set("auth_version", 1)
  e.next()
}, "users")
onRecordUpdate((e) => {
  const old = e.app.findRecordById(e.record.collection().name, e.record.id)
  if (used(e.app, "teaching_report_entries", "assignment", e.record.id)) {
    for (const field of ["teacher", "subject", "group", "academic_year"]) {
      if (old.getString(field) !== e.record.getString(field) || old.getInt(field) !== e.record.getInt(field)) fail("Used assignment is immutable")
    }
  }
  e.next()
}, "assignments")
onRecordUpdate((e) => {
  if (used(e.app, "assignments", e.record.collection().name === "subjects" ? "subject" : "group", e.record.id)) fail("Used reference is immutable")
  e.next()
}, "subjects", "groups")
onRecordDelete((e) => {
  const name = e.record.collection().name
  if ((name === "subjects" || name === "groups") && used(e.app, "assignments", name === "subjects" ? "subject" : "group", e.record.id)) fail("Used reference cannot be deleted")
  if (name === "assignments" && used(e.app, "teaching_report_entries", "assignment", e.record.id)) fail("Used assignment cannot be deleted")
  e.next()
}, "subjects", "groups", "assignments")
