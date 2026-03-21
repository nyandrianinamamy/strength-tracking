import Foundation
import WatchConnectivity
import WatchKit
import Combine

class WorkoutSessionManager: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WorkoutSessionManager()

    // MARK: - Published state

    @Published var snapshot: SessionSnapshot? = nil
    @Published var isConnected: Bool = false
    @Published var showWorkoutComplete: Bool = false
    @Published var syncFailed: Bool = false

    // MARK: - Private

    private let cacheKey = "cached_session_snapshot"
    private let queueKey = "queued_log_sets"
    private var wcSession: WCSession?

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
                self.flushQueue()
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
                    locale: locale,
                    unit: unit,
                    weightIncrement: increment
                )
                DispatchQueue.main.async {
                    self.snapshot = enriched
                    self.showWorkoutComplete = false
                }
                cacheSnapshot(enriched)
            } catch {
                print("Failed to decode session snapshot: \(error)")
            }

        case "session_end":
            DispatchQueue.main.async {
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

    // MARK: - Send logged set to phone

    func sendLogSet(_ message: LogSetMessage) {
        let dict = message.toDictionary()
        applyOptimisticLog(message)

        guard let session = wcSession, session.isReachable else {
            // Queue for later delivery
            enqueue(dict)
            return
        }

        // Try direct message first, fall back to guaranteed delivery if needed.
        session.sendMessage(dict, replyHandler: nil) { [weak self] error in
            print("Direct send failed, queuing: \(error)")
            self?.enqueue(dict)
        }
    }

    // MARK: - Force sync

    func forceSync() {
        flushQueue()

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

    // MARK: - Offline queue

    private func enqueue(_ dict: [String: Any]) {
        var queue = loadQueue()
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            queue.append(data)
            UserDefaults.standard.set(queue.map { $0.base64EncodedString() }, forKey: queueKey)
        }
    }

    private func loadQueue() -> [Data] {
        guard let encoded = UserDefaults.standard.array(forKey: queueKey) as? [String] else {
            return []
        }
        return encoded.compactMap { Data(base64Encoded: $0) }
    }

    func flushQueue() {
        let queue = loadQueue()
        guard let session = wcSession, session.isReachable, !queue.isEmpty else { return }

        for data in queue {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                session.transferUserInfo(dict)
            }
        }
        UserDefaults.standard.removeObject(forKey: queueKey)
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
        }
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    private func applyOptimisticLog(_ message: LogSetMessage) {
        guard let snapshot = snapshot,
              !snapshot.sessionId.isEmpty,
              snapshot.sessionId == message.sessionId,
              let exerciseIndex = snapshot.exercises.firstIndex(where: { $0.exerciseId == message.exerciseId }) else {
            return
        }

        let exercise = snapshot.exercises[exerciseIndex]
        guard !exercise.completedSets.contains(where: { $0.setNumber == message.setNumber }) else {
            return
        }

        let optimisticSet = WatchCompletedSet(
            setNumber: message.setNumber,
            weightKg: message.weightKg ?? 0,
            reps: message.reps ?? 0,
            durationSeconds: message.durationSeconds,
            completedAt: message.completedAt
        )

        let updatedExercise = WatchExercise(
            exerciseId: exercise.exerciseId,
            name: exercise.name,
            exerciseType: exercise.exerciseType,
            targetSets: exercise.targetSets,
            targetReps: exercise.targetReps,
            targetDurationSeconds: exercise.targetDurationSeconds,
            restSeconds: exercise.restSeconds,
            recommendedWeightKg: exercise.recommendedWeightKg,
            completedSets: exercise.completedSets + [optimisticSet]
        )

        var updatedExercises = snapshot.exercises
        updatedExercises[exerciseIndex] = updatedExercise
        let nextExerciseIndex: Int
        if exerciseIndex == snapshot.currentExerciseIndex &&
            updatedExercise.completedSets.count >= updatedExercise.targetSets &&
            exerciseIndex < updatedExercises.count - 1 {
            nextExerciseIndex = exerciseIndex + 1
        } else {
            nextExerciseIndex = snapshot.currentExerciseIndex
        }

        let updatedSnapshot = SessionSnapshot(
            sessionId: snapshot.sessionId,
            routineId: snapshot.routineId,
            routineName: snapshot.routineName,
            startedAt: snapshot.startedAt,
            currentExerciseIndex: nextExerciseIndex,
            exercises: updatedExercises,
            locale: snapshot.locale,
            unit: snapshot.unit,
            weightIncrement: snapshot.weightIncrement
        )

        DispatchQueue.main.async {
            self.snapshot = updatedSnapshot
        }
        cacheSnapshot(updatedSnapshot)
    }
}
