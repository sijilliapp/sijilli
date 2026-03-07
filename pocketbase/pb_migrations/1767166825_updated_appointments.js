migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // remove
  collection.schema.removeField("kxq7hkip")

  // remove
  collection.schema.removeField("xypk8fy9")

  // add
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
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

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

  // remove
  collection.schema.removeField("lbaxcjvi")

  return dao.saveCollection(collection)
})
