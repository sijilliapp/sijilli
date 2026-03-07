migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // remove
  collection.schema.removeField("qar0wcdm")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "rrcy4zcg",
    "name": "date_type",
    "type": "select",
    "required": true,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "gregorian",
        "hijri"
      ]
    }
  }))

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "c8ysfkla",
    "name": "duration_minutes",
    "type": "number",
    "required": false,
    "unique": false,
    "options": {
      "min": 1,
      "max": 1440
    }
  }))

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "lbaxcjvi",
    "name": "status_box",
    "type": "select",
    "required": true,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "active",
        "archived",
        "deleted"
      ]
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "qar0wcdm",
    "name": "use_hijri",
    "type": "bool",
    "required": false,
    "unique": false,
    "options": {}
  }))

  // remove
  collection.schema.removeField("rrcy4zcg")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "c8ysfkla",
    "name": "duration_minutes",
    "type": "number",
    "required": true,
    "unique": false,
    "options": {
      "min": 1,
      "max": 1440
    }
  }))

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "lbaxcjvi",
    "name": "status_box",
    "type": "select",
    "required": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "active",
        "archived",
        "is_deleted"
      ]
    }
  }))

  return dao.saveCollection(collection)
})
