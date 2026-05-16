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

    // MARK: - Private

    private let cacheKey = "cached_session_snapshot"
    private var wcSession: WCSession?
    private var restHapticTimer: Timer?
    private var activeRestKey: String?
    private var lastRestAlertSecond: Int?

    // MARK: - HealthKit Workout Session

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?

    private override init() {
        super.init()
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
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            let wasConnected = self.isConnected
            self.isConnected = session.isReachable
            // Haptic on reconnection
            if !wasConnected && self.isConnected {
                WKInterfaceDevice.current().play(.click)
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
        guard let type = data["type"] as? String else { return }

        switch type {
        case "session_update":
            guard let sessionData = data["session"] as? [String: Any] else { return }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: sessionData)
                let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: jsonData)
                // Attach locale/unit/increment from the outer payload
                let locale = data["locale"] as? String ?? "en"
                let unit = data["unit"] as? String ?? "kg"
                let increment = data["weightIncrement"] as? Double ?? 2.5
                let enriched = SessionSnapshot(
                    sessionId: decoded.sessionId,
                    routineId: decoded.routineId,
                    routineName: decoded.routineName,
                    startedAt: decoded.startedAt,
                    currentExerciseIndex: decoded.currentExerciseIndex,
                    exercises: decoded.exercises,
                    activeRest: decoded.activeRest,
                    locale: locale,
                    unit: unit,
                    weightIncrement: increment
                )
                DispatchQueue.main.async {
                    self.snapshot = enriched
                    self.showWorkoutComplete = false
                    self.startWorkoutSession()
                    self.configureActiveRest(enriched.activeRest)
                }
                cacheSnapshot(enriched)
            } catch {
                print("Failed to decode session snapshot: \(error)")
            }

        case "session_end":
            DispatchQueue.main.async {
                self.endWorkoutSession()
                self.resetActiveRest()
                self.showWorkoutComplete = true
                // Show "Workout Complete" for 3 seconds, then clear
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.snapshot = nil
                    self.showWorkoutComplete = false
                    self.clearCache()
                }
                WKInterfaceDevice.current().play(.success)
            }

        default:
            break
        }
    }

    // MARK: - Force sync

    func forceSync() {
        guard let session = wcSession, session.isReachable else {
            DispatchQueue.main.async {
                self.syncFailed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.syncFailed = false
                }
            }
            WKInterfaceDevice.current().play(.failure)
            return
        }

        // Request fresh snapshot
        session.sendMessage(["type": "request_sync"], replyHandler: { _ in
            WKInterfaceDevice.current().play(.success)
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.syncFailed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self?.syncFailed = false
                }
            }
            WKInterfaceDevice.current().play(.failure)
        })
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
        guard workoutSession == nil, HKHealthStore.isHealthDataAvailable() else { return }

        healthStore.requestAuthorization(toShare: [HKQuantityType.workoutType()], read: []) { [weak self] success, _ in
            guard success else { return }
            DispatchQueue.main.async {
                self?.beginWorkout()
            }
        }
    }

    private func beginWorkout() {
        guard workoutSession == nil else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.delegate = self
            session.startActivity(with: Date())
            workoutSession = session
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
        self.workoutSession = nil
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
            self.snapshot = cached
            configureActiveRest(cached.activeRest)
        }
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}
