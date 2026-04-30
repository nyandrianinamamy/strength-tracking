import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WatchSessionManager.shared.activateSession()
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "KotranaUrlOpener") {
      let channel = FlutterMethodChannel(
        name: "dev.mamy_r.kotrana/url_opener",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "openUrl" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let arguments = call.arguments as? [String: Any],
          let urlString = arguments["url"] as? String,
          let url = URL(string: urlString)
        else {
          result(FlutterError(code: "invalid_url", message: "Missing or invalid URL", details: nil))
          return
        }

        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
