migrate((db) => {
  const collection = new Collection({
    "id": "jz1m2vxznej7ajj",
    "created": "2025-12-29 10:20:46.128Z",
    "updated": "2025-12-29 10:20:46.128Z",
    "name": "appointments",
    "type": "base",
    "system": false,
    "schema": [
      {
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
      }
    ],
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("jz1m2vxznej7ajj");

  return dao.deleteCollection(collection);
})
