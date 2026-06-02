migrate((db) => {
  const collection = new Collection({
    "id": "commentsid12345",
    "created": "2026-06-02 12:00:00.000Z",
    "updated": "2026-06-02 12:00:00.000Z",
    "name": "comments",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "comment_article_rel",
        "name": "article",
        "type": "relation",
        "required": true,
        "unique": false,
        "options": {
          "maxSelect": 1,
          "collectionId": "pbc_1125843985",
          "cascadeDelete": true
        }
      },
      {
        "system": false,
        "id": "comment_user_rel",
        "name": "user",
        "type": "relation",
        "required": true,
        "unique": false,
        "options": {
          "maxSelect": 1,
          "collectionId": "_pb_users_auth_",
          "cascadeDelete": true
        }
      },
      {
        "system": false,
        "id": "comment_content_txt",
        "name": "content",
        "type": "text",
        "required": true,
        "unique": false,
        "options": {
          "min": 1,
          "max": 500,
          "pattern": ""
        }
      }
    ],
    "listRule": "",
    "viewRule": "",
    "createRule": "@request.auth.id != null && user = @request.auth.id",
    "updateRule": "@request.auth.id != null && @request.auth.id = user",
    "deleteRule": "@request.auth.id != null && (user = @request.auth.id || article.author = @request.auth.id || @request.auth.role = \"admin\")",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("commentsid12345");

  return dao.deleteCollection(collection);
});
