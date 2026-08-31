// Migration runners wrap this entire operation in a transaction.
// Keep auth record IDs, password hashes and tokens; move profile data and relations.
migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  const profiles = app.findCollectionByNameOrId("user_profiles")
  const accounts = app.findAllRecords(users)
  const oldProfiles = app.findAllRecords(profiles)
  const byUser = new Map()
  const byProfile = new Map()
  const knownFields = new Set(["id", "user", "display_name", "email", "role", "created", "updated"])
  for (const field of profiles.fields) {
    if (!knownFields.has(field.name)) {
      throw new Error("Preserve custom profile field before merging: " + field.name)
    }
  }
  if (users.fields.getByName("role")) {
    throw new Error("Resolve existing users.role field before merging profiles")
  }
  for (const profile of oldProfiles) {
    const userId = profile.getString("user")
    if (byUser.has(userId)) throw new Error("Multiple profiles for account: " + userId)
    byUser.set(userId, profile)
    byProfile.set(profile.id, userId)
  }
  for (const user of accounts) {
    const profile = byUser.get(user.id)
    if (!profile) throw new Error("Configure a profile before merging account: " + user.id)
    if (user.getString("email") !== profile.getString("email")) {
      throw new Error("Resolve account/profile email mismatch for account: " + user.id)
    }
    const name = user.getString("display_name")
    if (name && name !== profile.getString("display_name")) {
      throw new Error("Resolve account/profile display_name mismatch for account: " + user.id)
    }
  }
  if (accounts.length !== oldProfiles.length) {
    throw new Error("Resolve profiles without accounts before merging")
  }

  // Discover all incoming links, including the legacy confirmation on entries.
  // Unsupported custom links fail explicitly rather than deleting their data.
  const links = []
  for (const collection of app.findAllCollections()) {
    const fields = []
    for (const field of collection.fields) {
      if (field.type() !== "relation" || field.collectionId !== profiles.id) continue
      if (field.maxSelect !== 1 || collection.type === "view" || collection.id === profiles.id) {
        throw new Error("Migrate custom profile relation first: " + collection.name + "." + field.name)
      }
      fields.push(field)
    }
    if (!fields.length) continue
    for (const record of app.findAllRecords(collection)) {
      for (const field of fields) {
        const oldId = record.getString(field.name)
        if ((oldId && !byProfile.has(oldId)) || (!oldId && field.required)) {
          throw new Error("Invalid profile relation: " + collection.name + "." + field.name + " record " + record.id)
        }
      }
    }
    links.push({collection, fields})
  }

  users.fields.getByName("display_name").required = true
  users.fields.getByName("display_name").presentable = true
  users.fields.add(new SelectField({
    name: "role", required: true, maxSelect: 1, values: ["teacher", "admin"],
  }))
  for (const rule of ["listRule", "viewRule", "createRule", "updateRule", "deleteRule", "manageRule"]) {
    users[rule] = null
  }
  app.save(users)
  for (const account of accounts) {
    const profile = byUser.get(account.id)
    const user = app.findRecordById(users, account.id)
    user.set("display_name", profile.getString("display_name"))
    user.set("role", profile.getString("role"))
    app.save(user)
  }

  function quote(name) { return '"' + name.replace(/"/g, '""') + '"' }
  for (const {collection, fields} of links) {
    for (const field of fields) {
      // One SQL update avoids ID-overlap collisions and preserves report timestamps.
      const table = quote(collection.name)
      const column = quote(field.name)
      app.db().newQuery("UPDATE " + table + " SET " + column +
        " = (SELECT user FROM user_profiles WHERE id = " + table + "." + column + ")" +
        " WHERE " + column + " != ''").execute()
      collection.fields.getByName(field.name).collectionId = users.id
    }
    // PocketBase normally forbids changing a relation's target. The data above
    // has already been remapped and checked in this transaction. Preserve the
    // field IDs, indexes and columns using its migration-level save operation.
    app.saveNoValidate(collection)
    app.validate(collection)
  }
  app.delete(profiles)
}, () => {
  throw new Error("Restore a full pre-upgrade backup to roll back unified users.")
})
