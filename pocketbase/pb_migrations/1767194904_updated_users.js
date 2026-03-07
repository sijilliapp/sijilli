migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("_pb_users_auth_")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "u6n7ob6f",
    "name": "isPublic",
    "type": "text",
    "required": true,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "4fjtpiwe",
    "name": "role",
    "type": "select",
    "required": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "user",
        "approved",
        "admin"
      ]
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "tpzopovm",
    "name": "hijri_adjustment",
    "type": "number",
    "required": true,
    "unique": false,
    "options": {
      "min": -2,
      "max": 2
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "hdskq6jm",
    "name": "bio",
    "type": "text",
    "required": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "5znfl1y6",
    "name": "social_link",
    "type": "text",
    "required": false,
    "unique": false,
    "options": {
      "min": null,
      "max": 50,
      "pattern": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "kqxjksvt",
    "name": "phone",
    "type": "text",
    "required": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "5kekndy4",
    "name": "joining_date",
    "type": "date",
    "required": false,
    "unique": false,
    "options": {
      "min": "",
      "max": ""
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("_pb_users_auth_")

  // remove
  collection.schema.removeField("u6n7ob6f")

  // remove
  collection.schema.removeField("4fjtpiwe")

  // remove
  collection.schema.removeField("tpzopovm")

  // remove
  collection.schema.removeField("hdskq6jm")

  // remove
  collection.schema.removeField("5znfl1y6")

  // remove
  collection.schema.removeField("kqxjksvt")

  // remove
  collection.schema.removeField("5kekndy4")

  return dao.saveCollection(collection)
})
