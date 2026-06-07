migrate((db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("articles");

  collection.createRule = "@request.auth.role != \"user\"";

  return dao.saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("articles");

  collection.createRule = "@request.auth.id != \"user\"";

  return dao.saveCollection(collection);
});
