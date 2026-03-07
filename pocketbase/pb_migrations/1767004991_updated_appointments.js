migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "21ehougm",
    "name": "status",
    "type": "select",
    "required": true,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "pending",
        "accepted",
        "declined",
        "deleted"
      ]
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "kxq7hkip",
    "name": "is_archived",
    "type": "bool",
    "required": true,
    "unique": false,
    "options": {}
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "xypk8fy9",
    "name": "is_deleted",
    "type": "bool",
    "required": true,
    "unique": false,
    "options": {}
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "mry7j7yt",
    "name": "responded_at",
    "type": "date",
    "required": false,
    "unique": false,
    "options": {
      "min": "",
      "max": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "c8zaosgq",
    "name": "deleted_at",
    "type": "date",
    "required": false,
    "unique": false,
    "options": {
      "min": "",
      "max": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "dp6z6akt",
    "name": "archived_at",
    "type": "date",
    "required": false,
    "unique": false,
    "options": {
      "min": "",
      "max": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "dbndmo4m",
    "name": "personal_notes",
    "type": "text",
    "required": false,
    "unique": false,
    "options": {
      "min": null,
      "max": 1000,
      "pattern": ""
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "spkxhrhj",
    "name": "color_tag",
    "type": "text",
    "required": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": "^#([A-Fa-f0-9]{6})$"
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // remove
  collection.schema.removeField("21ehougm")

  // remove
  collection.schema.removeField("kxq7hkip")

  // remove
  collection.schema.removeField("xypk8fy9")

  // remove
  collection.schema.removeField("mry7j7yt")

  // remove
  collection.schema.removeField("c8zaosgq")

  // remove
  collection.schema.removeField("dp6z6akt")

  // remove
  collection.schema.removeField("dbndmo4m")

  // remove
  collection.schema.removeField("spkxhrhj")

  return dao.saveCollection(collection)
})
