migrate((app) => {
  const collection = app.findCollectionByNameOrId("assignments")
  collection.fields.add(new BoolField({name: "is_archived"}))
  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("assignments")
  collection.fields.removeByName("is_archived")
  app.save(collection)
})
