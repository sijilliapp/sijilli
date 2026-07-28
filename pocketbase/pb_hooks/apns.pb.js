onRecordAfterCreateRequest((e) => {
  const record = e.record;
  
  // Get target user ID from notification record
  const userId = record.get("user");
  const title = record.get("title");
  const message = record.get("message");
  const type = record.get("type");
  const relatedId = record.get("related_id");

  // Configure your Vercel endpoint here (Change this to your actual Vercel domain)
  const VERCEL_PUSH_URL = "https://sijilli.vercel.app/api/push";

  try {
    // Fetch target user's apnsToken
    const user = $app.dao().findRecordById("users", userId);
    const apnsToken = user.get("apnsToken");

    if (apnsToken) {
      console.log("🔔 [APNs Hook] Sending push notification to user: " + userId + " (Token: " + apnsToken + ")");
      
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
        console.log("✅ [APNs Hook] Push notification sent successfully.");
      } else {
        console.log("⚠️ [APNs Hook] Vercel returned status " + response.statusCode + ": " + response.raw);
      }
    } else {
      console.log("ℹ️ [APNs Hook] No apnsToken found for user: " + userId);
    }
  } catch (err) {
    console.log("❌ [APNs Hook] Error sending push: " + err.message);
  }
}, "notifications");
