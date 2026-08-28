// PocketBase migrations for mgkct_vuchet
// Creates collections: users (+display_name), user_profiles, assignments, vychitki, zameny

migrate(
  (app) => {
    const authReq = "@request.auth.id != ''"

    // 1. Extend the built-in users (auth) collection with display_name
    {
      let users = app.findCollectionByNameOrId("users")
      if (users.fields.getByName("display_name") == null) {
        users.fields.add(new TextField({
          name: "display_name",
          required: false,
          max: 200,
        }))
        app.save(users)
      }
    }

    // 2. user_profiles (base)
    let profiles = new Collection({
      type: "base",
      name: "user_profiles",
      // guest может искать профиль по display_name для нахождения email (логин)
      listRule: "",
      viewRule: "",
      createRule: authReq,
      updateRule: authReq,
      deleteRule: null,
    })
    profiles.fields.add(new RelationField({
      name: "user",
      required: true,
      maxSelect: 1,
      collectionId: app.findCollectionByNameOrId("users").id,
      cascadeDelete: true,
    }))
    profiles.fields.add(new SelectField({
      name: "role",
      required: true,
      maxSelect: 1,
      values: ["teacher", "admin"],
    }))
    profiles.fields.add(new TextField({
      name: "display_name",
      required: true,
      max: 200,
    }))
    profiles.fields.add(new EmailField({
      name: "email",
      required: true,
    }))
    app.save(profiles)

    const profilesId = app.findCollectionByNameOrId("user_profiles").id

    // 3. assignments (base)
    let assignments = new Collection({
      type: "base",
      name: "assignments",
      listRule: authReq,
      viewRule: authReq,
      createRule: null,
      updateRule: null,
      deleteRule: null,
    })
    assignments.fields.add(new RelationField({
      name: "teacher",
      required: true,
      maxSelect: 1,
      collectionId: profilesId,
      cascadeDelete: false,
    }))
    assignments.fields.add(new TextField({ name: "subject", required: true, max: 200 }))
    assignments.fields.add(new TextField({ name: "group", required: true, max: 200 }))
    assignments.fields.add(new NumberField({ name: "year", required: true }))
    app.save(assignments)

    const assignmentsId = app.findCollectionByNameOrId("assignments").id

    // 4. vychitki (base)
    let vychitki = new Collection({
      type: "base",
      name: "vychitki",
      listRule: authReq,
      viewRule: authReq,
      createRule: authReq,
      updateRule: authReq,
      deleteRule: null,
    })
    vychitki.fields.add(new RelationField({
      name: "assignment",
      required: true,
      maxSelect: 1,
      collectionId: assignmentsId,
      cascadeDelete: true,
    }))
    vychitki.fields.add(new TextField({ name: "month", required: true, max: 100 }))
    vychitki.fields.add(new NumberField({ name: "year", required: true }))
    vychitki.fields.add(new NumberField({ name: "lek", required: false, min: 0 }))
    vychitki.fields.add(new NumberField({ name: "lrPr", required: false, min: 0 }))
    vychitki.fields.add(new NumberField({ name: "kp", required: false, min: 0 }))
    vychitki.fields.add(new NumberField({ name: "cons", required: false, min: 0 }))
    vychitki.fields.add(new NumberField({ name: "dopKontr", required: false, min: 0 }))
    vychitki.fields.add(new NumberField({ name: "ekz", required: false, min: 0 }))
    vychitki.fields.add(new SelectField({
      name: "status",
      required: true,
      maxSelect: 1,
      values: ["draft", "submitted", "confirmed"],
    }))
    vychitki.fields.add(new DateField({ name: "submitted_at" }))
    vychitki.fields.add(new DateField({ name: "confirmed_at" }))
    vychitki.fields.add(new RelationField({
      name: "confirmed_by",
      maxSelect: 1,
      collectionId: profilesId,
    }))
    app.save(vychitki)

    // 5. zameny (base)
    let zameny = new Collection({
      type: "base",
      name: "zameny",
      listRule: authReq,
      viewRule: authReq,
      createRule: authReq,
      updateRule: authReq,
      deleteRule: authReq,
    })
    zameny.fields.add(new RelationField({
      name: "teacher",
      required: true,
      maxSelect: 1,
      collectionId: profilesId,
      cascadeDelete: true,
    }))
    zameny.fields.add(new TextField({ name: "month", required: true, max: 100 }))
    zameny.fields.add(new NumberField({ name: "year", required: true }))
    zameny.fields.add(new TextField({ name: "group", required: true, max: 200 }))
    zameny.fields.add(new TextField({ name: "date", required: true, max: 100 }))
    zameny.fields.add(new NumberField({ name: "hours", required: true, min: 0 }))
    app.save(zameny)
  },
  (app) => {
    for (const name of ["zameny", "vychitki", "assignments", "user_profiles"]) {
      try {
        const c = app.findCollectionByNameOrId(name)
        app.delete(c)
      } catch (e) {
        // already deleted
      }
    }
  }
)
