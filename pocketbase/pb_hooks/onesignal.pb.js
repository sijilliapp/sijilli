// 📍 pocketbase/pb_hooks/onesignal.pb.js
// 🔔 PocketBase JS Hook to automatically trigger OneSignal Push Notifications for iOS & Android

onRecordAfterCreate((e) => {
  const record = e.record;
  if (!record) return;

  const userId = record.get("user");
  const title = record.get("title");
  const message = record.get("message");
  const type = record.get("type");
  const relatedId = record.get("related_id");

  if (!userId) {
    $app.logger().info("ℹ️ [OneSignal Hook] No user ID associated with notification: " + record.id);
    return;
  }

  // 🔑 OneSignal Credentials
  const ONESIGNAL_APP_ID = "c6b787e8-372e-413a-b64a-31704ff17821";
  
  // ⚠️ IMPORTANT: Replace this placeholder with your actual OneSignal REST API Key
  // You can find this in OneSignal Dashboard -> Settings -> Keys & IDs -> REST API Key
  const ONESIGNAL_REST_API_KEY = "YOUR_ONESIGNAL_REST_API_KEY";

  if (ONESIGNAL_REST_API_KEY === "YOUR_ONESIGNAL_REST_API_KEY") {
    $app.logger().warn("⚠️ [OneSignal Hook] Please configure your actual OneSignal REST API Key in pb_hooks/onesignal.pb.js");
    return;
  }

  try {
    $app.logger().info("🔔 [OneSignal Hook] Triggering push for user: " + userId);

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
          external_id: [userId]
        },
        target_channel: "push",
        headings: { en: title, ar: title },
        contents: { en: message, ar: message },
        content_available: true,
        mutable_content: true,
        priority: 10,
        data: {
          type: type,
          relatedId: relatedId || ""
        }
      })
    });

    if (response.statusCode === 200) {
      $app.logger().info("✅ [OneSignal Hook] Push notification request sent successfully to OneSignal.");
    } else {
      $app.logger().error("⚠️ [OneSignal Hook] OneSignal API returned status " + response.statusCode + ": " + response.raw);
    }
  } catch (err) {
    $app.logger().error("❌ [OneSignal Hook] Error sending push: " + err.message);
  }
}, "notifications");
