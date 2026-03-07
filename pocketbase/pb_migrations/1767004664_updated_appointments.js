migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "svviv5fy",
    "name": "privacy",
    "type": "select",
    "required": true,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "private",
        "followers",
        "public"
      ]
    }
  }))

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

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // remove
  collection.schema.removeField("svviv5fy")

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
      "max": null
    }
  }))

  return dao.saveCollection(collection)
})
