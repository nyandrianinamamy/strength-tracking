import Foundation
import WatchConnectivity
import Flutter

class WatchSessionManager: NSObject, WCSessionDelegate, FlutterStreamHandler {

    static let shared = WatchSessionManager()

    private var session: WCSession?
    private var methodChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func configure(with controller: FlutterViewController) {
        // Method channel for Dart → iOS
        methodChannel = FlutterMethodChannel(
            name: "com.strengthapp/watch",
            binaryMessenger: controller.binaryMessenger
        )
        methodChannel?.setMethodCallHandler(handleMethodCall)

        // Event channel for iOS → Dart (Watch messages)
        let eventChannel = FlutterEventChannel(
            name: "com.strengthapp/watch_events",
            binaryMessenger: controller.binaryMessenger
        )
        eventChannel.setStreamHandler(self)

        // Activate WCSession
        if WCSession.isSupported() {
            let wcSession = WCSession.default
            wcSession.delegate = self
            wcSession.activate()
            session = wcSession
        }
    }

    // MARK: - Flutter → Watch (MethodChannel handler)

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "sendSessionUpdate":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected dictionary", details: nil))
                return
            }
            sendToWatch(args)
            result(nil)

        case "sendSessionEnd":
            sendToWatch(["type": "session_end"])
            result(nil)

        case "isWatchPaired":
            result(session?.isPaired ?? false)

        case "isWatchReachable":
            result(session?.isReachable ?? false)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Send to Watch

    private func sendToWatch(_ message: [String: Any]) {
        guard let session = session, session.isPaired else { return }

        let isSessionEnd = (message["type"] as? String) == "session_end"

        // Try direct message if reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Direct send to Watch failed: \(error), using fallback")
                if isSessionEnd {
                    session.transferUserInfo(message)
                } else {
                    try? session.updateApplicationContext(message)
                }
            }
        } else if isSessionEnd {
            // session_end must be delivered reliably
            session.transferUserInfo(message)
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("Failed to update application context: \(error)")
            }
        }

        // Always send session_end via transferUserInfo as backup
        if isSessionEnd {
            session.transferUserInfo(message)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activated: \(activationState.rawValue), error: \(String(describing: error))")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate
        session.activate()
    }

    // Receive direct message from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleWatchMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleWatchMessage(message)
        replyHandler(["status": "ok"])
    }

    // Receive guaranteed delivery from Watch (transferUserInfo)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleWatchMessage(userInfo)
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "log_set", "log_timed_set":
            // Forward to Flutter via EventChannel
            DispatchQueue.main.async {
                self.eventSink?(message)
            }

        case "request_sync":
            // Forward sync request to Flutter
            DispatchQueue.main.async {
                self.eventSink?(["type": "request_sync"])
            }

        default:
            break
        }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
