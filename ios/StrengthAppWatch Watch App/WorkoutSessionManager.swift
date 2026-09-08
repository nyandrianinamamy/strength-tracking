import Foundation
import WatchConnectivity
import WatchKit
import Combine
import HealthKit

class WorkoutSessionManager: NSObject, ObservableObject, WCSessionDelegate, HKWorkoutSessionDelegate {

    static let shared = WorkoutSessionManager()

    // MARK: - Published state

    @Published var snapshot: SessionSnapshot? = nil
    @Published var isConnected: Bool = false
    @Published var showWorkoutComplete: Bool = false
    @Published var syncFailed: Bool = false
    @Published var activeRestRemaining: Int = 0
    @Published var locale = WorkoutStrings.locale(UserDefaults.standard.string(forKey: "watch_locale") ?? Locale.preferredLanguages.first ?? "en")

    // MARK: - Private

    private let cacheKey = "cached_session_snapshot"
    private var wcSession: WCSession?
    private var restHapticTimer: Timer?
    private var activeRestKey: String?
    private var lastRestAlertSecond: Int?
    private var messageState = WatchMessageState()
    private var completionClear: DispatchWorkItem?
    private var pendingSyncRequestID: String?
    private var syncRequestedAt: Date?
    private var authorizationPending = false
    private var authorizationRequested = false

    // MARK: - HealthKit Workout Session

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?

    private override init() {
        super.init()
        UserDefaults.standard.set(false, forKey: "watch_health_authorization_pending")
        if let data = UserDefaults.standard.data(forKey: "watch_message_state_v2"),
           let saved = try? JSONDecoder().decode(WatchMessageState.self, from: data) {
            messageState = saved
        }
        loadCachedSnapshot()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated && session.isReachable)
            if self.isConnected { self.requestSync(showFailure: false) }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            let wasConnected = self.isConnected
            self.isConnected = session.isReachable
            // Haptic on reconnection
            if !wasConnected && self.isConnected {
                WKInterfaceDevice.current().play(.click)
                self.requestSync(showFailure: false)
            }
        }
    }

    // Receive application context (latest session snapshot)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncoming(applicationContext)
    }

    // Receive direct message
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncoming(message)
        replyHandler(["status": "ok"])
    }

    // Receive user info (guaranteed delivery)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncoming(userInfo)
    }

    // MARK: - Message handling

    private func handleIncoming(_ data: [String: Any]) {
        DispatchQueue.main.async { self.applyIncoming(data) }
    }

    private func applyIncoming(_ data: [String: Any]) {
        guard let envelope = WatchEnvelope(dictionary: data) else { return }
        var incomingSnapshot: SessionSnapshot?
        if envelope.type == "session_update" {
            guard let sessionData = data["session"] as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: sessionData),
                  var decoded = try? JSONDecoder().decode(SessionSnapshot.self, from: encoded),
                  decoded.sessionId == envelope.sessionID else { return }
            decoded.locale = WorkoutStrings.locale(data["locale"] as? String ?? locale)
            decoded.unit = data["unit"] as? String ?? "kg"
            incomingSnapshot = decoded
        }
        let action = messageState.accept(envelope, expectedSyncRequestID: pendingSyncRequestID)
        if action == .requestSync { requestSync(showFailure: false); return }
        if action == .ignore { return }
        if envelope.syncRequestID == pendingSyncRequestID {
            pendingSyncRequestID = nil
            syncRequestedAt = nil
            syncFailed = false
        }
        locale = WorkoutStrings.locale(data["locale"] as? String ?? locale)
        UserDefaults.standard.set(locale, forKey: "watch_locale")
        if let stateData = try? JSONEncoder().encode(messageState) {
            UserDefaults.standard.set(stateData, forKey: "watch_message_state_v2")
        }
        completionClear?.cancel()
        completionClear = nil
        switch action {
        case .update:
            guard let incomingSnapshot else { return }
            snapshot = incomingSnapshot
            showWorkoutComplete = false
            cacheSnapshot(incomingSnapshot)
            configureActiveRest(incomingSnapshot.activeRest)
            startWorkoutSession()
        case .complete:
            endWorkoutSession()
            resetActiveRest()
            clearCache()
            showWorkoutComplete = true
            let clear = DispatchWorkItem { [weak self] in
                guard let self,
                      self.messageState.canClearCompletion(senderID: envelope.senderID, revision: envelope.revision) else { return }
                self.snapshot = nil
                self.showWorkoutComplete = false
            }
            completionClear = clear
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: clear)
            WKInterfaceDevice.current().play(.success)
        case .idle:
            endWorkoutSession()
            resetActiveRest()
            clearCache()
            snapshot = nil
            showWorkoutComplete = false
        case .ignore, .requestSync:
            break
        }
    }

    // MARK: - Force sync

    func forceSync() { requestSync(showFailure: true) }

    private func requestSync(showFailure: Bool) {
        guard let session = wcSession, session.isReachable else {
            if showFailure { reportSyncFailure() }
            return
        }
        if !showFailure, pendingSyncRequestID != nil,
           let syncRequestedAt, Date().timeIntervalSince(syncRequestedAt) < 10 { return }
        let nonce = UUID().uuidString
        pendingSyncRequestID = nonce
        syncRequestedAt = Date()
        session.sendMessage(["type": "request_sync", "syncRequestId": nonce], replyHandler: { _ in
            // Only the matching state response confirms synchronization.
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.pendingSyncRequestID == nonce else { return }
                self.pendingSyncRequestID = nil
                if showFailure { self.reportSyncFailure() }
            }
        })
    }

    private func reportSyncFailure() {
        syncFailed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.syncFailed = false }
        WKInterfaceDevice.current().play(.failure)
    }

    // MARK: - Active rest

    private func configureActiveRest(_ rest: WatchRestState?) {
        restHapticTimer?.invalidate()
        restHapticTimer = nil

        guard let rest,
              let endsAt = parseISO8601(rest.endsAt) else {
            resetActiveRest()
            return
        }

        let key = "\(rest.sourceExerciseId)|\(rest.startedAt)|\(rest.endsAt)"
        if activeRestKey != key {
            activeRestKey = key
            lastRestAlertSecond = nil
        }

        updateActiveRestRemaining(endsAt: endsAt)
        guard activeRestRemaining > 0 else {
            resetActiveRest()
            return
        }

        restHapticTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.updateActiveRestRemaining(endsAt: endsAt)
            self.playRestHapticIfNeeded()
            if self.activeRestRemaining <= 0 {
                timer.invalidate()
                self.restHapticTimer = nil
            }
        }
    }

    private func updateActiveRestRemaining(endsAt: Date) {
        activeRestRemaining = max(0, Int(ceil(endsAt.timeIntervalSinceNow)))
    }

    private func playRestHapticIfNeeded() {
        let remaining = activeRestRemaining
        guard lastRestAlertSecond != remaining else { return }
        lastRestAlertSecond = remaining

        if remaining == 3 || remaining == 2 || remaining == 1 {
            WKInterfaceDevice.current().play(.click)
        } else if remaining == 0 {
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func resetActiveRest() {
        restHapticTimer?.invalidate()
        restHapticTimer = nil
        activeRestRemaining = 0
        activeRestKey = nil
        lastRestAlertSecond = nil
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    // MARK: - HKWorkoutSession

    private func startWorkoutSession() {
        guard workoutSession == nil, !authorizationPending,
              messageState.activeSessionID != nil, HKHealthStore.isHealthDataAvailable() else { return }
        let type = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: type)
        UserDefaults.standard.set(status.rawValue, forKey: "watch_health_authorization")
        if status == .sharingAuthorized { beginWorkout(); return }
        guard status == .notDetermined, !authorizationRequested else { return }
        authorizationRequested = true
        authorizationPending = true
        UserDefaults.standard.set(true, forKey: "watch_health_authorization_pending")
        healthStore.requestAuthorization(toShare: [type], read: []) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                let status = self.healthStore.authorizationStatus(for: type)
                let nativeError = error as NSError?
                NSLog("Health authorization completed: success=%@ errorDomain=%@ errorCode=%ld status=%ld",
                      success ? "true" : "false", nativeError?.domain ?? "none", nativeError?.code ?? 0, status.rawValue)
                self.settleWorkoutAuthorization(status: status, settlement: HealthAuthorizationSettlement())
            }
        }
    }

    private func settleWorkoutAuthorization(status: HKAuthorizationStatus, settlement: HealthAuthorizationSettlement) {
        var nextSettlement = settlement
        UserDefaults.standard.set(status.rawValue, forKey: "watch_health_authorization")
        switch nextSettlement.observe(isNotDetermined: status == .notDetermined) {
        case .recheck(let delay):
            let pendingSettlement = nextSettlement
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                let currentStatus = self.healthStore.authorizationStatus(for: HKObjectType.workoutType())
                self.settleWorkoutAuthorization(status: currentStatus, settlement: pendingSettlement)
            }
        case .settled, .exhausted:
            authorizationPending = false
            UserDefaults.standard.set(false, forKey: "watch_health_authorization_pending")
            NSLog("Health authorization observation finished: status=%ld", status.rawValue)
            // Permission may settle after A ended or B replaced it. The current
            // session and existing HealthKit-session guards in beginWorkout apply.
            if status == .sharingAuthorized { beginWorkout() }
        case .finished:
            break
        }
    }

    private func beginWorkout() {
        guard workoutSession == nil, messageState.activeSessionID != nil else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.delegate = self
            workoutSession = session
            session.startActivity(with: Date())
        } catch {
            print("Failed to start HKWorkoutSession: \(error)")
        }
    }

    private func endWorkoutSession() {
        workoutSession?.end()
        workoutSession = nil
    }

    // MARK: - HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // No-op — we only care about keeping the app foregrounded
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("HKWorkoutSession failed: \(error)")
        DispatchQueue.main.async {
            if self.workoutSession === workoutSession { self.workoutSession = nil }
        }
    }

    // MARK: - Cache

    private func cacheSnapshot(_ snapshot: SessionSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCachedSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        if let cached = try? JSONDecoder().decode(SessionSnapshot.self, from: data) {
            if messageState.senderID != nil && messageState.activeSessionID != cached.sessionId {
                clearCache()
                return
            }
            self.snapshot = cached
            configureActiveRest(cached.activeRest)
        }
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}
