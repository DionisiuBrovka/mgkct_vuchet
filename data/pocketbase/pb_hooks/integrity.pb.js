// Storage invariants for direct PB administration. Shelf owns workflow.
// Write the derived key before PocketBase's required-field validation.
onRecordCreate((e) => {
  e.record.set("normalized_name", e.record.getString("name").trim().replace(/\s+/g, " ").toLowerCase())
  e.next()
}, "subjects", "groups")
onRecordUpdate((e) => {
  e.record.set("normalized_name", e.record.getString("name").trim().replace(/\s+/g, " ").toLowerCase())
  e.next()
}, "subjects", "groups")
onRecordCreate((e) => {
  if (!e.record.get("is_active")) e.record.set("is_active", true)
  if (e.record.getInt("auth_version") < 1) e.record.set("auth_version", 1)
  e.next()
}, "users")
