migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "j3isvwop",
    "name": "participants_count",
    "type": "number",
    "required": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // remove
  collection.schema.removeField("j3isvwop")

  return dao.saveCollection(collection)
})
