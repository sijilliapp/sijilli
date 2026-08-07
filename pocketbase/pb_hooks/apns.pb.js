onRecordAfterCreate((e) => {
  const record = e.record;
  if (!record) return;

  const userId = record.get("user");
  const title = record.get("title");
  const message = record.get("message");
  const type = record.get("type");
  const relatedId = record.get("related_id");

  const VERCEL_PUSH_URL = "https://sijilli.vercel.app/api/push";

  if (!userId) {
    $app.logger().info("ℹ️ [APNs Hook] No user ID associated with notification: " + record.id);
    return;
  }

  try {
    const user = $app.dao().findRecordById("users", userId);
    if (!user) {
      $app.logger().info("ℹ️ [APNs Hook] User not found in database: " + userId);
      return;
    }

    const apnsToken = user.get("apnsToken");
    if (!apnsToken) {
      $app.logger().info("ℹ️ [APNs Hook] No apnsToken found for user: " + userId);
      return;
    }

    $app.logger().info("🔔 [APNs Hook] Sending push notification to user: " + userId + " (Token: " + apnsToken + ")");

    const response = $http.send({
      url: VERCEL_PUSH_URL,
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        deviceToken: apnsToken,
        title: title,
        body: message,
        type: type,
        relatedId: relatedId
      })
    });

    if (response.statusCode === 200) {
      $app.logger().info("✅ [APNs Hook] Push notification sent successfully.");
    } else {
      $app.logger().error("⚠️ [APNs Hook] Vercel returned status " + response.statusCode + ": " + response.raw);
    }
  } catch (err) {
    $app.logger().error("❌ [APNs Hook] Error sending push: " + err.message);
  }
}, "notifications");
