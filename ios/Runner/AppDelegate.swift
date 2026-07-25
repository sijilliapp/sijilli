import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static var apnsToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let apnsChannel = FlutterMethodChannel(name: "com.sijilli.app/apns",
                                           binaryMessenger: controller.binaryMessenger)
    
    apnsChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getAPNSToken" {
        result(AppDelegate.apnsToken)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    // Register for remote notifications
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    AppDelegate.apnsToken = token
    print("Device Token: \(token)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
