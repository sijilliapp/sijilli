migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // remove
  collection.schema.removeField("q4enoy6x")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "mbplejhu",
    "name": "hijri_date",
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
    "id": "x4zo28zo",
    "name": "hijri_day",
    "type": "number",
    "required": false,
    "unique": false,
    "options": {
      "min": 1,
      "max": 30
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "7nthetiz",
    "name": "hijri_month",
    "type": "number",
    "required": false,
    "unique": false,
    "options": {
      "min": 1,
      "max": 12
    }
  }))

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "qbjnelmu",
    "name": "hijri_year",
    "type": "number",
    "required": false,
    "unique": false,
    "options": {
      "min": 1440,
      "max": 1500
    }
  }))

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

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "dxed4tq9",
    "name": "date_display",
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
    "id": "rykbwo1g",
    "name": "user_id",
    "type": "relation",
    "required": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "collectionId": "_pb_users_auth_",
      "cascadeDelete": false
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "q4enoy6x",
    "name": "user_id",
    "type": "text",
    "required": true,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": ""
    }
  }))

  // remove
  collection.schema.removeField("mbplejhu")

  // remove
  collection.schema.removeField("x4zo28zo")

  // remove
  collection.schema.removeField("7nthetiz")

  // remove
  collection.schema.removeField("qbjnelmu")

  // remove
  collection.schema.removeField("qar0wcdm")

  // remove
  collection.schema.removeField("dxed4tq9")

  // remove
  collection.schema.removeField("rykbwo1g")

  return dao.saveCollection(collection)
})
