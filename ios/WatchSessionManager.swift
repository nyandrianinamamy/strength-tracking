import Foundation
import HealthKit
import WatchConnectivity
import Flutter

class WatchSessionManager: NSObject, WCSessionDelegate, FlutterStreamHandler {

    static let shared = WatchSessionManager()

    private var session: WCSession?
    private var methodChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?
    private var pendingEvents: [[String: Any]] = []
    private var pendingOutboundMessage: [String: Any]?
    private var latestOutboundMessage: [String: Any]?
    private var pendingSyncRequestID: String?
    private let senderID: String = {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: "watch_sender_id_v2") { return saved }
        let id = UUID().uuidString
        defaults.set(id, forKey: "watch_sender_id_v2")
        return id
    }()
    private var revision = UserDefaults.standard.object(forKey: "watch_revision_v2") as? Int64 ?? 0
    private let healthStore = HKHealthStore()
    private var launchPolicy = WatchLaunchPolicy()

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func activateSession() {
        guard WCSession.isSupported() else { return }
        let wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        session = wcSession
    }

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

        activateSession()
    }

    // MARK: - Flutter → Watch (MethodChannel handler)

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "sendSessionUpdate":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected dictionary", details: nil))
                return
            }
            guard let sessionData = args["session"] as? [String: Any],
                  let sessionID = sessionData["sessionId"] as? String, !sessionID.isEmpty else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing session identity", details: nil))
                return
            }
            var message = sanitizedMessage(args)
            message["type"] = "session_update"
            message["sessionId"] = sessionID
            publish(message)
            result(nil)

        case "sendSessionEnd":
            let args = call.arguments as? [String: Any] ?? [:]
            let sessionID = args["sessionId"] as? String ?? latestOutboundMessage?["sessionId"] as? String
            launchPolicy.reset()
            var message = args
            message["type"] = sessionID == nil ? "session_idle" : "session_end"
            message["sessionId"] = sessionID
            publish(message)
            result(nil)

        case "sendSessionIdle":
            var message = call.arguments as? [String: Any] ?? [:]
            message["type"] = "session_idle"
            message.removeValue(forKey: "sessionId")
            launchPolicy.reset()
            publish(message)
            result(nil)

        case "isWatchPaired":
            result(session?.isPaired ?? false)

        case "isWatchReachable":
            result(session?.isReachable ?? false)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Auto-launch Watch App

    /// Launches the watch companion app via HealthKit when a new workout session
    /// starts and the watch is paired. Only triggers once per session.
    private func launchWatchAppIfNeeded(_ message: [String: Any]) {
        guard let sessionData = message["session"] as? [String: Any],
              let sessionId = sessionData["sessionId"] as? String,
              let wcSession = session, wcSession.isPaired,
              HKHealthStore.isHealthDataAvailable() else { return }

        guard launchPolicy.shouldLaunch(sessionID: sessionId, isReachable: wcSession.isReachable) else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        // This phone bridge does not read or save workouts. The Watch requests
        // its own authorization when it starts a HealthKit workout session.
        healthStore.startWatchApp(with: config) { _, error in
            if let error { print("Failed to launch watch app: \(error)") }
        }
    }

    // MARK: - Send to Watch

    private func publish(_ payload: [String: Any]) {
        revision += 1
        UserDefaults.standard.set(revision, forKey: "watch_revision_v2")
        var message = sanitizedMessage(payload)
        if let pendingSyncRequestID { message["syncRequestId"] = pendingSyncRequestID }
        pendingSyncRequestID = nil
        message["protocolVersion"] = 2
        message["senderId"] = senderID
        message["revision"] = revision
        latestOutboundMessage = message
        sendToWatch(message)
    }

    private func sendToWatch(_ message: [String: Any]) {
        guard let session = session else {
            queueOutboundMessage(message)
            return
        }
        guard session.activationState == .activated else {
            queueOutboundMessage(message)
            return
        }
        guard session.isPaired else {
            queueOutboundMessage(message)
            return
        }

        if message["type"] as? String == "session_update" {
            launchWatchAppIfNeeded(message)
        }
        // Context is the authoritative latest state, including idle/end. It
        // coalesces while disconnected; revision checks deduplicate direct
        // delivery and prevent a later callback from restoring older context.
        do {
            try session.updateApplicationContext(message)
            pendingOutboundMessage = nil
        } catch {
            queueOutboundMessage(message)
            print("Failed to update application context: \(error)")
        }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Direct send to Watch failed; latest application context remains queued: \(error)")
            }
        }
    }

    private func queueOutboundMessage(_ message: [String: Any]) {
        pendingOutboundMessage = message
    }

    private func flushPendingOutboundMessage() {
        guard let message = pendingOutboundMessage else { return }
        pendingOutboundMessage = nil
        sendToWatch(message)
    }

    private func sanitizedMessage(_ message: [String: Any]) -> [String: Any] {
        sanitizePropertyListValue(message) as? [String: Any] ?? [:]
    }

    private func sanitizePropertyListValue(_ value: Any) -> Any? {
        if value is NSNull { return nil }

        if let dictionary = value as? [String: Any] {
            var sanitized: [String: Any] = [:]
            for (key, nestedValue) in dictionary {
                if let cleanValue = sanitizePropertyListValue(nestedValue) {
                    sanitized[key] = cleanValue
                }
            }
            return sanitized
        }

        if let array = value as? [Any] {
            return array.compactMap { sanitizePropertyListValue($0) }
        }

        switch value {
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return value.boolValue
            }
            return value
        case let value as String:
            return value
        case let value as Bool:
            return value
        case let value as Int:
            return value
        case let value as Double:
            return value
        case let value as Float:
            return value
        case let value as Date:
            return value
        case let value as Data:
            return value
        default:
            return nil
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activated: \(activationState.rawValue), error: \(String(describing: error))")
        DispatchQueue.main.async { self.flushPendingOutboundMessage() }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            if self.pendingOutboundMessage == nil { self.pendingOutboundMessage = self.latestOutboundMessage }
            self.flushPendingOutboundMessage()
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.flushPendingOutboundMessage() }
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

        let forwardedMessage: [String: Any]
        switch type {
        case "request_sync":
            forwardedMessage = message

        default:
            return
        }

        DispatchQueue.main.async {
            if type == "request_sync", let nonce = message["syncRequestId"] as? String {
                self.pendingSyncRequestID = nonce
                // Reply from the latest native state even if Flutter is still
                // rebuilding its snapshot or has not attached its event sink.
                if let latest = self.latestOutboundMessage { self.publish(latest) }
            }
            if let sink = self.eventSink {
                sink(forwardedMessage)
            } else {
                self.pendingEvents.append(forwardedMessage)
            }
        }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        let bufferedEvents = pendingEvents
        pendingEvents.removeAll()
        for event in bufferedEvents {
            events(event)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
