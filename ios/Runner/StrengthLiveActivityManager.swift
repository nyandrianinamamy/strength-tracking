import ActivityKit
import Flutter
import Foundation
import UserNotifications

final class StrengthLiveActivityManager: NSObject {
    static let shared = StrengthLiveActivityManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private var lifecycle = WorkoutLifecycle()
    private var activityTask: Task<Void, Never>?
    private var notificationTask: Task<Void, Never>?
    private var notificationIdentifiers = Set(UserDefaults.standard.stringArray(forKey: "rest_notification_ids") ?? ["strengthapp.rest-timer"])
    private let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private let localDateFormatterWithFractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter
    }()
    private let localDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private var methodChannel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    func configure(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.strengthapp/live_activity",
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler(handleMethodCall)
        methodChannel = channel
    }

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "syncWorkout":
            guard let dictionary = Self.dictionary(from: call.arguments),
                  let payload = StrengthLiveActivityPayload(dictionary: dictionary) else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS",
                        message: "Expected live activity payload",
                        details: Self.payloadDebugDetails(from: call.arguments)
                    )
                )
                return
            }

            let token = beginChange(sessionID: payload.sessionId)
            let previous = activityTask
            activityTask = Task { @MainActor in
                await previous?.value
                guard lifecycle.isCurrent(token) else { result(nil); return }
                do {
                    try await syncActivity(payload: payload, token: token)
                    result(nil)
                } catch {
                    result(FlutterError(code: "ACTIVITY_ERROR", message: error.localizedDescription, details: nil))
                }
            }
            notificationTask = Task { @MainActor in
                await scheduleRestNotification(for: payload, token: token)
            }

        case "endWorkout":
            let token = beginChange(sessionID: nil)
            let previous = activityTask
            activityTask = Task { @MainActor in
                await previous?.value
                await endAllActivities(token: token)
                result(nil)
            }

#if DEBUG
        case "getWorkoutState":
            Task { @MainActor in
                let requests = await notificationCenter.pendingNotificationRequests()
                var activities: [[String: Any]] = []
                if #available(iOS 16.2, *) {
                    activities = Activity<StrengthLiveActivityAttributes>.activities.map {
                        ["sessionId": $0.attributes.sessionId,
                         "currentExerciseName": $0.content.state.currentExerciseName,
                         "currentExerciseIndex": $0.content.state.currentExerciseIndex,
                         "completedSetsText": $0.content.state.completedSetsText,
                         "currentExerciseProgressText": $0.content.state.currentExerciseProgressText,
                         "locale": $0.content.state.locale ?? "en"]
                    }
                }
                result(["activities": activities,
                        "pendingRestNotifications": requests.filter { $0.identifier.hasPrefix("strengthapp.rest-timer") }.map { $0.identifier }])
            }
#endif

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.2, *)
    private func existingActivity(sessionId: String) -> Activity<StrengthLiveActivityAttributes>? {
        Activity<StrengthLiveActivityAttributes>.activities.first { activity in
            activity.attributes.sessionId == sessionId
        }
    }

    private func beginChange(sessionID: String?) -> WorkoutLifecycle.Token {
        let token = lifecycle.advance(sessionID: sessionID)
        notificationTask?.cancel()
        cancelRestNotification()
        return token
    }

    private func syncActivity(payload: StrengthLiveActivityPayload, token: WorkoutLifecycle.Token) async throws {
        guard #available(iOS 16.2, *) else { return }
        guard lifecycle.isCurrent(token), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = StrengthLiveActivityAttributes(
            sessionId: payload.sessionId,
            routineName: payload.routineName,
            startedAt: payload.startedAt
        )
        let contentState = StrengthLiveActivityAttributes.ContentState(
            currentExerciseName: payload.currentExerciseName,
            currentExerciseType: payload.currentExerciseType,
            currentExerciseIndex: payload.currentExerciseIndex,
            totalExercises: payload.totalExercises,
            completedSetsText: payload.completedSetsText,
            currentExerciseProgressText: payload.currentExerciseProgressText,
            exerciseDetailText: payload.exerciseDetailText,
            updatedAt: payload.updatedAt,
            restEndAt: payload.restEndAt,
            restSeconds: payload.restSeconds,
            hasActiveRest: payload.hasActiveRest,
            locale: payload.locale
        )
        let content = ActivityContent(
            state: contentState,
            staleDate: nil
        )

        if let activity = existingActivity(sessionId: payload.sessionId) {
            await activity.update(content)
        } else {
            for activity in Activity<StrengthLiveActivityAttributes>.activities {
                guard lifecycle.isCurrent(token) else { return }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            guard lifecycle.isCurrent(token) else { return }
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        }

    }

    private func endAllActivities(token: WorkoutLifecycle.Token) async {
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<StrengthLiveActivityAttributes>.activities {
            guard lifecycle.isCurrent(token) else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func scheduleRestNotification(for payload: StrengthLiveActivityPayload, token: WorkoutLifecycle.Token) async {
        guard let restEndAt = payload.restEndAt,
              lifecycle.restInterval(token: token, endsAt: restEndAt, now: Date()) != nil else { return }

        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            guard granted else { return }
        } catch {
            return
        }

        guard !Task.isCancelled,
              let interval = lifecycle.restInterval(token: token, endsAt: restEndAt, now: Date()) else { return }
        let identifier = "strengthapp.rest-timer." + UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = WorkoutStrings.string("rest_complete", locale: payload.locale)
        content.body = WorkoutStrings.notificationBody(exercise: payload.currentExerciseName, locale: payload.locale)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: min(interval, TimeInterval(Int.max)),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        notificationIdentifiers.insert(identifier)
        persistNotificationIdentifiers()
        do {
            try await notificationCenter.add(request)
        } catch {
            removeRestNotification(identifier)
            return
        }
        // add() can finish after endWorkout has cancelled this task. Its
        // identifier is unique, so removing it cannot delete a newer alert.
        if Task.isCancelled || !lifecycle.isCurrent(token) {
            removeRestNotification(identifier)
        }
    }

    private func persistNotificationIdentifiers() {
        UserDefaults.standard.set(Array(notificationIdentifiers), forKey: "rest_notification_ids")
    }

    private func removeRestNotification(_ identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationIdentifiers.remove(identifier)
        persistNotificationIdentifiers()
    }

    private func cancelRestNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(notificationIdentifiers))
        notificationIdentifiers.removeAll()
        persistNotificationIdentifiers()
    }

    fileprivate func parseDate(_ rawValue: Any?) -> Date? {
        guard let stringValue = rawValue as? String else { return nil }
        return isoFormatterWithFractionalSeconds.date(from: stringValue)
            ?? isoFormatter.date(from: stringValue)
            ?? localDateFormatterWithFractionalSeconds.date(from: stringValue)
            ?? localDateFormatter.date(from: stringValue)
    }

    private static func dictionary(from arguments: Any?) -> [String: Any]? {
        if let dictionary = arguments as? [String: Any] {
            return dictionary
        }

        if let dictionary = arguments as? [AnyHashable: Any] {
            var normalized: [String: Any] = [:]
            for (key, value) in dictionary {
                guard let key = key as? String else { continue }
                normalized[key] = value
            }
            return normalized.isEmpty ? nil : normalized
        }

        return nil
    }

    private static func payloadDebugDetails(from arguments: Any?) -> [String: String] {
        guard let dictionary = dictionary(from: arguments) else {
            return [
                "argumentType": String(describing: type(of: arguments)),
                "keys": "<not a dictionary>",
            ]
        }

        var details: [String: String] = [:]
        for (key, value) in dictionary {
            details[key] = String(describing: type(of: value))
        }
        return details
    }
}

private struct StrengthLiveActivityPayload {
    let sessionId: String
    let routineName: String
    let currentExerciseName: String
    let currentExerciseType: String
    let currentExerciseIndex: Int
    let totalExercises: Int
    let completedSetsText: String
    let currentExerciseProgressText: String
    let exerciseDetailText: String
    let startedAt: Date
    let updatedAt: Date
    let restEndAt: Date?
    let restSeconds: Int
    let hasActiveRest: Bool
    let locale: String

    init?(dictionary: [String: Any]) {
        let parser = StrengthLiveActivityManager.shared

        guard let sessionId = Self.stringValue(dictionary["sessionId"]),
              let routineName = Self.stringValue(dictionary["routineName"]),
              let currentExerciseName = Self.stringValue(dictionary["currentExerciseName"]),
              let currentExerciseType = Self.stringValue(dictionary["currentExerciseType"]),
              let currentExerciseIndex = Self.intValue(dictionary["currentExerciseIndex"]),
              let totalExercises = Self.intValue(dictionary["totalExercises"]),
              let completedSetsText = Self.stringValue(dictionary["completedSetsText"]),
              let currentExerciseProgressText = Self.stringValue(dictionary["currentExerciseProgressText"]),
              let exerciseDetailText = Self.stringValue(dictionary["exerciseDetailText"]),
              let startedAt = parser.parseDate(dictionary["startedAt"]),
              let updatedAt = parser.parseDate(dictionary["updatedAt"]),
              let restSeconds = Self.intValue(dictionary["restSeconds"]),
              let hasActiveRest = Self.boolValue(dictionary["hasActiveRest"]) else {
            return nil
        }

        self.sessionId = sessionId
        self.routineName = routineName
        self.currentExerciseName = currentExerciseName
        self.currentExerciseType = currentExerciseType
        self.currentExerciseIndex = currentExerciseIndex
        self.totalExercises = totalExercises
        self.completedSetsText = completedSetsText
        self.currentExerciseProgressText = currentExerciseProgressText
        self.exerciseDetailText = exerciseDetailText
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.restEndAt = parser.parseDate(dictionary["restEndAt"])
        self.restSeconds = restSeconds
        self.hasActiveRest = hasActiveRest
        self.locale = WorkoutStrings.locale(dictionary["locale"] as? String ?? "en")
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}
