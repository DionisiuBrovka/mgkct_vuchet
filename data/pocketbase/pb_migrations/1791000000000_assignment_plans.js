migrate((app) => {
  const collection = app.findCollectionByNameOrId("assignments")
  // Existing assignments have no known plan; blank must not become a zero plan.
  for (const name of ["planned_main_hours", "planned_additional_hours"]) {
    collection.fields.add(new TextField({name, max: 1048576, pattern: "^(0|[1-9][0-9]*)(\\.[0-9]*[1-9])?$"}))
  }
  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("assignments")
  for (const name of ["planned_main_hours", "planned_additional_hours"]) collection.fields.removeByName(name)
  app.save(collection)
})
