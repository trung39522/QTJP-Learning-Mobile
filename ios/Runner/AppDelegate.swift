import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var notificationChannel: FlutterMethodChannel?
  private var openedNotification = false
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QtjpNotifications") else { return }
    let channel = FlutterMethodChannel(name: "qtjp/device_notifications", binaryMessenger: registrar.messenger())
    notificationChannel = channel
    UNUserNotificationCenter.current().delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "status":
        center.getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .authorized, .provisional: status = "enabled"
          case .notDetermined: status = "notDetermined"
          default: status = "denied"
          }
          DispatchQueue.main.async { result(status) }
        }
      case "request":
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
          DispatchQueue.main.async {
            if let error = error { result(FlutterError(code: "PERMISSION", message: error.localizedDescription, details: nil)) }
            else { result(granted ? "enabled" : "denied") }
          }
        }
      case "settings":
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        result(nil)
      case "show":
        guard let data = call.arguments as? [String: Any], let id = data["id"] as? NSNumber else {
          result(FlutterError(code: "INVALID", message: "Missing notification ID", details: nil)); return
        }
        let content = UNMutableNotificationContent()
        content.title = String((data["title"] as? String ?? "QTJP Learning").prefix(160))
        content.body = String((data["body"] as? String ?? "").prefix(500))
        content.sound = .default
        content.userInfo = ["qtjp_notification": true]
        center.add(UNNotificationRequest(identifier: "qtjp-\(id)", content: content, trigger: nil)) { error in
          DispatchQueue.main.async {
            if let error = error { result(FlutterError(code: "DELIVERY", message: error.localizedDescription, details: nil)) }
            else { result(nil) }
          }
        }
      case "clear":
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        result(nil)
      case "consumeTap":
        result(self?.openedNotification ?? false)
        self?.openedNotification = false
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if notification.request.content.userInfo["qtjp_notification"] as? Bool == true {
      if #available(iOS 14.0, *) { completionHandler([.banner, .list, .sound]) }
      else { completionHandler([.alert, .sound]) }
    } else { super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler) }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    if response.notification.request.content.userInfo["qtjp_notification"] as? Bool == true {
      if let channel = notificationChannel { channel.invokeMethod("opened", arguments: nil) }
      else { openedNotification = true }
      completionHandler()
    } else { super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler) }
  }
}
