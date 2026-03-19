import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configure Watch connectivity bridge
    if let controller = window?.rootViewController as? FlutterViewController {
      WatchSessionManager.shared.configure(with: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
