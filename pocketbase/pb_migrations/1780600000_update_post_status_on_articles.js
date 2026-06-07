migrate((db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("articles");

  const existingField = collection.schema.getFieldByName("post_status");
  const fieldId = existingField ? existingField.id : "post_status_field";

  collection.schema.addField(new SchemaField({
    "system": false,
    "id": fieldId,
    "name": "post_status",
    "type": "select",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "written",
        "published",
        "draft",
        "archived",
        "trash"
      ]
    }
  }));

  return dao.saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("articles");

  const existingField = collection.schema.getFieldByName("post_status");
  const fieldId = existingField ? existingField.id : "post_status_field";

  collection.schema.addField(new SchemaField({
    "system": false,
    "id": fieldId,
    "name": "post_status",
    "type": "select",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSelect": 1,
      "values": [
        "published",
        "draft",
        "archived",
        "trash"
      ]
    }
  }));

  return dao.saveCollection(collection);
});
