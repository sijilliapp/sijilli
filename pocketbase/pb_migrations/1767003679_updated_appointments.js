migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "q4enoy6x",
    "name": "df",
    "type": "text",
    "required": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": ""
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // update
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "q4enoy6x",
    "name": "field",
    "type": "text",
    "required": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": ""
    }
  }))

  return dao.saveCollection(collection)
})
