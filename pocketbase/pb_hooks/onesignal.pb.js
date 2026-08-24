onRecordCreate((e) => {
  e.next();
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

  // 🛡️ check recipient notification preferences from DB
  try {
    const recipientUser = $app.findRecordById("users", userId);
    const settingsStr = recipientUser.get("notification_settings");
    if (settingsStr) {
      const settings = JSON.parse(settingsStr);
      
      if (settings.notify_all === false) {
        $app.logger().info("🔇 [OneSignal Hook] Push skipped: User " + userId + " has globally disabled notifications.");
        return;
      }

      // Check if it is a salute (greeting)
      const isSalute = title.indexOf("التحية") !== -1 || message.indexOf("تحية") !== -1 || message.indexOf("👋") !== -1;
      if (isSalute && settings.notify_salutes === false) {
        $app.logger().info("🔇 [OneSignal Hook] Push skipped: User " + userId + " has disabled salute notifications.");
        return;
      }

      // Check follows
      if (type === "follow" && settings.notify_follows === false) {
        $app.logger().info("🔇 [OneSignal Hook] Push skipped: User " + userId + " has disabled follow notifications.");
        return;
      }

      // Check invites & cancellations
      const isInvite = type === "invite" || type === "cancel" || type === "approval_request";
      if (isInvite && settings.notify_invites === false) {
        $app.logger().info("🔇 [OneSignal Hook] Push skipped: User " + userId + " has disabled invite notifications.");
        return;
      }

      // Check visits
      if (type === "visit" && settings.notify_visits === false) {
        $app.logger().info("🔇 [OneSignal Hook] Push skipped: User " + userId + " has disabled profile visit notifications.");
        return;
      }

      // Check reminders
      if (type === "reminder" && settings.notify_reminders === false) {
        $app.logger().info("🔇 [OneSignal Hook] Push skipped: User " + userId + " has disabled reminder notifications.");
        return;
      }
    }
  } catch (err) {
    $app.logger().warn("⚠️ [OneSignal Hook] Error loading recipient preferences for user " + userId + ": " + err.message);
  }

  // 🔑 OneSignal Credentials
  const ONESIGNAL_APP_ID = "c6b787e8-372e-413a-b64a-31704ff17821";
  
  // ⚠️ SECURITY NOTE: Do NOT commit your REST API Key to GitHub (GitHub Push Protection will block it).
  // The hook will attempt to load the key from the server environment variable: 'ONESIGNAL_REST_API_KEY'
  // Or you can configure it locally on your running server directly in this file without pushing it to GitHub.
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
  } catch (err) {
    // Fallback if environment access fails
  }

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
