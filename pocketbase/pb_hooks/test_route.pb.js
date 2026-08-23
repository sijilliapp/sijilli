// 📍 pocketbase/pb_hooks/test_route.pb.js
routerAdd("GET", "/api/sijilli-test-push/{userId}", (c) => {
  try {
    const targetUserId = c.request.pathValue("userId") || "test_user_id";
    
    let ONESIGNAL_REST_API_KEY = "YOUR_ONESIGNAL_REST_API_KEY";
    try {
      if (typeof process !== "undefined" && process.env && process.env.ONESIGNAL_REST_API_KEY) {
        ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;
      } else {
        const envKey = $os.getenv("ONESIGNAL_REST_API_KEY");
        if (envKey) {
          ONESIGNAL_REST_API_KEY = envKey;
        }
      }
    } catch (err) {}

    const ONESIGNAL_APP_ID = "c6b787e8-372e-413a-b64a-31704ff17821";

    const response = $http.send({
      url: "https://onesignal.com/api/v1/notifications",
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": "Basic " + ONESIGNAL_REST_API_KEY
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_aliases: {
          external_id: [targetUserId]
        },
        target_channel: "push",
        headings: { en: "Sijilli Test" },
        contents: { en: "Testing background push notifications sync!" }
      })
    });

    return c.json(200, {
      targetUserId: targetUserId,
      oneSignalResponseStatus: response.statusCode,
      oneSignalResponseBody: response.raw
    });
  } catch (err) {
    return c.json(500, { error: err.message });
  }
});
