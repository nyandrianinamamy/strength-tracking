# Apple Watch Companion — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native WatchOS companion app that displays workout information and allows set logging from the wrist during active sessions, communicating with the Flutter iOS app via WCSession.

**Architecture:** Three-layer bridge — a Dart `WatchSyncService` listens to `AppStateController` state changes and pushes session snapshots over a `MethodChannel` named `com.strengthapp/watch`; a Swift `WatchSessionManager` on the iOS side bridges the MethodChannel to WCSession; a SwiftUI WatchOS app receives snapshots, caches them in UserDefaults, renders per-exercise swipeable pages, and sends `log_set`/`log_timed_set` messages back through the same chain. Phone starts workouts; Watch joins automatically. Watch works offline from its cached snapshot, queuing logged sets for delivery via `transferUserInfo` (guaranteed FIFO).

**Tech Stack:** Flutter MethodChannel (Dart), WatchConnectivity + FlutterMethodChannel (Swift iOS), SwiftUI + WCSession + UserDefaults (WatchOS), Xcode WatchOS target

---

### Task 1: Create the WatchOS app target in Xcode

**Files:**
- Create: `ios/StrengthAppWatch/` directory (WatchOS app target)
- Create: `ios/StrengthAppWatch/StrengthAppWatchApp.swift`
- Create: `ios/StrengthAppWatch/ContentView.swift`
- Create: `ios/StrengthAppWatch/Assets.xcassets/` (watch app icon)
- Create: `ios/StrengthAppWatch/Info.plist`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (via Xcode)

**Step 1: Add WatchOS target in Xcode**

Open `ios/Runner.xcworkspace` in Xcode. File → New → Target → watchOS → App.

Configure:
- Product Name: `StrengthAppWatch`
- Bundle Identifier: `com.strengthapp.watch` (must share the same team and base bundle ID prefix as the iOS app, e.g., if iOS is `com.example.strengthTrainingTracker`, Watch should be `com.example.strengthTrainingTracker.watchkitapp`)
- Interface: SwiftUI
- Language: Swift
- Watch App: Watch-only App
- Deployment Target: watchOS 8.0+
- Embed in Companion: `Runner`

Xcode will create the `StrengthAppWatch/` folder and update `project.pbxproj`.

**Step 2: Replace the generated StrengthAppWatchApp.swift with a placeholder**

Replace the contents of `ios/StrengthAppWatch/StrengthAppWatchApp.swift`:

```swift
import SwiftUI

@main
struct StrengthAppWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Step 3: Replace ContentView.swift with idle state placeholder**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("StrengthApp")
                .font(.headline)
            Text("No active workout")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Start one on your iPhone")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
```

**Step 4: Verify build**

In Xcode, select the `StrengthAppWatch` scheme and build for a Watch simulator.

Expected: Builds successfully, shows idle state text on Watch simulator.

**Step 5: Commit**

```bash
git add ios/StrengthAppWatch/ ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: add WatchOS app target with idle state placeholder"
```

---

### Task 2: Create the WatchOS data models

**Files:**
- Create: `ios/StrengthAppWatch/Models/SessionSnapshot.swift`
- Create: `ios/StrengthAppWatch/Models/WatchExercise.swift`
- Create: `ios/StrengthAppWatch/Models/WatchCompletedSet.swift`
- Create: `ios/StrengthAppWatch/Models/LogSetMessage.swift`

**Step 1: Create SessionSnapshot model**

This model mirrors the `session_update` JSON payload from the design doc. It is what the Watch receives from the phone and caches in UserDefaults.

```swift
// ios/StrengthAppWatch/Models/SessionSnapshot.swift
import Foundation

struct SessionSnapshot: Codable {
    let routineId: String
    let routineName: String
    let startedAt: String
    let currentExerciseIndex: Int
    let exercises: [WatchExercise]
    let locale: String
    let unit: String
    let weightIncrement: Double
}
```

**Step 2: Create WatchExercise model**

```swift
// ios/StrengthAppWatch/Models/WatchExercise.swift
import Foundation

struct WatchExercise: Codable, Identifiable {
    let exerciseId: String
    let name: String
    let exerciseType: String // "strength" or "timed"
    let targetSets: Int
    let targetReps: Int
    let targetDurationSeconds: Int?
    let restSeconds: Int
    let recommendedWeightKg: Double
    let completedSets: [WatchCompletedSet]

    var id: String { exerciseId }

    var isStrength: Bool { exerciseType == "strength" }
    var isTimed: Bool { exerciseType == "timed" }
}
```

**Step 3: Create WatchCompletedSet model**

```swift
// ios/StrengthAppWatch/Models/WatchCompletedSet.swift
import Foundation

struct WatchCompletedSet: Codable, Identifiable {
    let setNumber: Int
    let weightKg: Double
    let reps: Int
    let durationSeconds: Int?
    let completedAt: String

    var id: Int { setNumber }
}
```

**Step 4: Create LogSetMessage model**

This is what the Watch sends back to the phone when the user logs a set.

```swift
// ios/StrengthAppWatch/Models/LogSetMessage.swift
import Foundation

struct LogSetMessage: Codable {
    let type: String // "log_set" or "log_timed_set"
    let exerciseId: String
    let setNumber: Int
    let weightKg: Double?       // nil for timed sets
    let reps: Int?              // nil for timed sets
    let durationSeconds: Int?   // nil for strength sets
    let completedAt: String

    static func strength(exerciseId: String, setNumber: Int, weightKg: Double, reps: Int) -> LogSetMessage {
        return LogSetMessage(
            type: "log_set",
            exerciseId: exerciseId,
            setNumber: setNumber,
            weightKg: weightKg,
            reps: reps,
            durationSeconds: nil,
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    static func timed(exerciseId: String, setNumber: Int, durationSeconds: Int) -> LogSetMessage {
        return LogSetMessage(
            type: "log_timed_set",
            exerciseId: exerciseId,
            setNumber: setNumber,
            weightKg: nil,
            reps: nil,
            durationSeconds: durationSeconds,
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "exerciseId": exerciseId,
            "setNumber": setNumber,
            "completedAt": completedAt,
        ]
        if let w = weightKg { dict["weightKg"] = w }
        if let r = reps { dict["reps"] = r }
        if let d = durationSeconds { dict["durationSeconds"] = d }
        return dict
    }
}
```

**Step 5: Verify build**

Select `StrengthAppWatch` scheme in Xcode → Build.

Expected: Builds successfully.

**Step 6: Commit**

```bash
git add ios/StrengthAppWatch/Models/
git commit -m "feat: add WatchOS data models for session snapshot and log messages"
```

---

### Task 3: Create the WatchOS localization dictionary

**Files:**
- Create: `ios/StrengthAppWatch/WatchLocalizations.swift`

**Step 1: Create localization dictionary**

The Watch receives `locale` ("en" or "fr") from the phone in the session payload and uses it to look up hardcoded strings.

```swift
// ios/StrengthAppWatch/WatchLocalizations.swift
import Foundation

struct WatchL10n {
    static func string(_ key: String, locale: String) -> String {
        return strings[locale]?[key] ?? strings["en"]![key] ?? key
    }

    static func setOf(_ current: Int, _ total: Int, locale: String) -> String {
        let template = string("set_of", locale: locale)
        return String(format: template, current, total)
    }

    private static let strings: [String: [String: String]] = [
        "en": [
            "resting": "Resting",
            "set_of": "SET %d/%d",
            "log_set": "LOG SET",
            "confirm_weight_reps": "CONFIRM WEIGHT & REPS",
            "next": "NEXT",
            "session": "SESSION",
            "reps": "reps",
            "force_sync": "Force Sync",
            "sync_failed": "Sync failed — try again",
            "no_active_workout": "No active workout",
            "start_on_iphone": "Start one on your iPhone",
            "workout_complete": "Workout Complete",
            "start": "START",
            "stop": "STOP",
            "open_on_iphone": "Open StrengthApp on your iPhone",
            "install_on_iphone": "Install StrengthApp on your iPhone",
        ],
        "fr": [
            "resting": "Repos",
            "set_of": "SERIE %d/%d",
            "log_set": "VALIDER",
            "confirm_weight_reps": "CONFIRMER POIDS & REPS",
            "next": "SUIVANT",
            "session": "SESSION",
            "reps": "reps",
            "force_sync": "Forcer la synchro",
            "sync_failed": "Echec synchro — reessayer",
            "no_active_workout": "Aucun entrainement actif",
            "start_on_iphone": "Lancez-en un sur votre iPhone",
            "workout_complete": "Entrainement termine",
            "start": "DEMARRER",
            "stop": "STOP",
            "open_on_iphone": "Ouvrez StrengthApp sur votre iPhone",
            "install_on_iphone": "Installez StrengthApp sur votre iPhone",
        ],
    ]
}
```

**Step 2: Verify build**

Build the WatchOS target.

Expected: Builds successfully.

**Step 3: Commit**

```bash
git add ios/StrengthAppWatch/WatchLocalizations.swift
git commit -m "feat: add WatchOS hardcoded EN/FR localization dictionary"
```

---

### Task 4: Create the WatchOS WorkoutSessionManager (WCSession + cache)

**Files:**
- Create: `ios/StrengthAppWatch/WorkoutSessionManager.swift`

**Step 1: Create WorkoutSessionManager**

This is the central manager on the Watch side. It:
- Activates `WCSession` and receives messages from the phone
- Caches the latest `SessionSnapshot` in UserDefaults
- Queues logged sets for delivery via `transferUserInfo`
- Publishes state as an `ObservableObject` for SwiftUI

```swift
// ios/StrengthAppWatch/WorkoutSessionManager.swift
import Foundation
import WatchConnectivity
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
                var decoded = try JSONDecoder().decode(SessionSnapshot.self, from: jsonData)
                // Attach locale/unit/increment from the outer payload
                let locale = data["locale"] as? String ?? "en"
                let unit = data["unit"] as? String ?? "kg"
                let increment = data["weightIncrement"] as? Double ?? 2.5
                decoded = SessionSnapshot(
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
                    self.snapshot = decoded
                    self.showWorkoutComplete = false
                }
                cacheSnapshot(decoded)
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

        guard let session = wcSession, session.isReachable else {
            // Queue for later delivery
            enqueue(dict)
            return
        }

        // Try direct message first, fall back to transferUserInfo
        session.sendMessage(dict, replyHandler: nil) { [weak self] error in
            print("Direct send failed, queuing: \(error)")
            self?.enqueue(dict)
        }

        // Also send via transferUserInfo for guaranteed delivery
        session.transferUserInfo(dict)
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
        guard let session = wcSession, !queue.isEmpty else { return }

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
}
```

**Step 2: Add WatchConnectivity and WatchKit imports**

Ensure the WatchOS target links `WatchConnectivity.framework` and `WatchKit.framework`. In Xcode: `StrengthAppWatch` target → General → Frameworks → add `WatchConnectivity` and `WatchKit` if not already present.

**Step 3: Update StrengthAppWatchApp.swift to activate the session manager**

```swift
// ios/StrengthAppWatch/StrengthAppWatchApp.swift
import SwiftUI

@main
struct StrengthAppWatchApp: App {
    @StateObject private var sessionManager = WorkoutSessionManager.shared

    init() {
        WorkoutSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}
```

**Step 4: Verify build**

Build the WatchOS target.

Expected: Builds successfully.

**Step 5: Commit**

```bash
git add ios/StrengthAppWatch/WorkoutSessionManager.swift ios/StrengthAppWatch/StrengthAppWatchApp.swift
git commit -m "feat: add WatchOS WorkoutSessionManager with WCSession, cache, and offline queue"
```

---

### Task 5: Build the WatchOS exercise page UI (strength exercises)

**Files:**
- Create: `ios/StrengthAppWatch/Views/ExercisePageView.swift`
- Create: `ios/StrengthAppWatch/Views/StrengthExerciseView.swift`

**Step 1: Create StrengthExerciseView**

This is the single-screen layout for one strength exercise, showing set progress, weight/reps with Digital Crown adjustment, LOG SET button, rest timer, and next exercise preview.

```swift
// ios/StrengthAppWatch/Views/StrengthExerciseView.swift
import SwiftUI
import WatchKit

struct StrengthExerciseView: View {
    let exercise: WatchExercise
    let exerciseIndex: Int
    let totalExercises: Int
    let nextExerciseName: String?
    let sessionStartedAt: String
    let locale: String
    let unit: String
    let weightIncrement: Double
    let onLogSet: (Double, Int) -> Void

    @State private var weight: Double = 0
    @State private var reps: Int = 8
    @State private var editingWeight: Bool = true // true = crown edits weight, false = reps
    @State private var restTimerStart: Date? = nil
    @State private var restRemaining: Int = 0
    @State private var timer: Timer? = nil

    private var nextSetNumber: Int {
        exercise.completedSets.count + 1
    }

    private var allSetsComplete: Bool {
        exercise.completedSets.count >= exercise.targetSets
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Rest timer pill
                if let _ = restTimerStart, restRemaining > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        Text("\(WatchL10n.string("resting", locale: locale)): \(formatTime(restRemaining))")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(12)
                }

                // Set progress
                Text(WatchL10n.setOf(min(nextSetNumber, exercise.targetSets), exercise.targetSets, locale: locale))
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Exercise name
                Text(exercise.name)
                    .font(.headline)
                    .bold()
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Weight and reps
                HStack(spacing: 4) {
                    Text(formatWeight(weight, unit: unit))
                        .font(.title3)
                        .bold()
                        .foregroundColor(editingWeight ? .blue : .primary)
                        .onTapGesture { editingWeight = true }

                    Text("x")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(reps) \(WatchL10n.string("reps", locale: locale))")
                        .font(.title3)
                        .bold()
                        .foregroundColor(!editingWeight ? .blue : .primary)
                        .onTapGesture { editingWeight = false }
                }
                .focusable(true)
                .digitalCrownRotation(
                    editingWeight
                        ? Binding(
                            get: { weight },
                            set: { newValue in
                                let clamped = max(0, newValue)
                                if clamped != weight {
                                    weight = clamped
                                }
                                if clamped <= 0 {
                                    WKInterfaceDevice.current().play(.directionDown)
                                }
                            }
                          )
                        : Binding(
                            get: { Double(reps) },
                            set: { newValue in
                                let newReps = max(1, Int(newValue))
                                if newReps != reps {
                                    reps = newReps
                                }
                                if newReps <= 1 {
                                    WKInterfaceDevice.current().play(.directionDown)
                                }
                            }
                          ),
                    from: 0,
                    through: editingWeight ? 500 : 100,
                    by: editingWeight ? weightIncrement : 1,
                    sensitivity: .medium
                )

                // LOG SET button
                if !allSetsComplete {
                    Button(action: logSet) {
                        VStack(spacing: 2) {
                            Text(WatchL10n.string("log_set", locale: locale))
                                .font(.headline)
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                } else {
                    Text("✓")
                        .font(.title2)
                        .foregroundColor(.green)
                }

                // Next exercise + session time
                HStack {
                    if let next = nextExerciseName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WatchL10n.string("next", locale: locale))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(next)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(WatchL10n.string("session", locale: locale))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(elapsedSessionTime())
                            .font(.caption2)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .onAppear { prefillValues() }
        .onChange(of: exercise.completedSets.count) { _ in prefillValues() }
    }

    // MARK: - Helpers

    private func prefillValues() {
        if let lastSet = exercise.completedSets.last {
            // Subsequent sets: use previous set's weight
            weight = lastSet.weightKg
            reps = exercise.targetReps
        } else {
            // First set: use recommended weight
            weight = exercise.recommendedWeightKg
            reps = exercise.targetReps
        }
    }

    private func logSet() {
        onLogSet(weight, reps)
        WKInterfaceDevice.current().play(.success)

        // Start rest timer
        restTimerStart = Date()
        restRemaining = exercise.restSeconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let elapsed = Int(Date().timeIntervalSince(restTimerStart ?? Date()))
            let remaining = exercise.restSeconds - elapsed
            DispatchQueue.main.async {
                restRemaining = max(0, remaining)
                // Haptic countdown at 3, 2, 1
                if remaining == 3 || remaining == 2 || remaining == 1 {
                    WKInterfaceDevice.current().play(.click)
                }
                if remaining <= 0 {
                    timer?.invalidate()
                    timer = nil
                    restTimerStart = nil
                }
            }
        }
    }

    private func formatWeight(_ kg: Double, unit: String) -> String {
        let value = unit == "lbs" ? kg * 2.20462 : kg
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))\(unit)"
        }
        return String(format: "%.1f%@", value, unit)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func elapsedSessionTime() -> String {
        let formatter = ISO8601DateFormatter()
        guard let start = formatter.date(from: sessionStartedAt) else { return "0:00" }
        let elapsed = Int(Date().timeIntervalSince(start))
        return formatTime(elapsed)
    }
}
```

**Step 2: Create ExercisePageView (horizontal paging container)**

```swift
// ios/StrengthAppWatch/Views/ExercisePageView.swift
import SwiftUI

struct ExercisePageView: View {
    let snapshot: SessionSnapshot
    let onLogSet: (String, Int, Double, Int) -> Void        // exerciseId, setNumber, weightKg, reps
    let onLogTimedSet: (String, Int, Int) -> Void            // exerciseId, setNumber, durationSeconds

    @State private var selectedPage: Int = 0

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(Array(snapshot.exercises.enumerated()), id: \.element.id) { index, exercise in
                Group {
                    if exercise.isTimed {
                        TimedExerciseView(
                            exercise: exercise,
                            exerciseIndex: index,
                            totalExercises: snapshot.exercises.count,
                            nextExerciseName: nextName(after: index),
                            sessionStartedAt: snapshot.startedAt,
                            locale: snapshot.locale,
                            onLogTimedSet: { durationSeconds in
                                let setNumber = exercise.completedSets.count + 1
                                onLogTimedSet(exercise.exerciseId, setNumber, durationSeconds)
                            }
                        )
                    } else {
                        StrengthExerciseView(
                            exercise: exercise,
                            exerciseIndex: index,
                            totalExercises: snapshot.exercises.count,
                            nextExerciseName: nextName(after: index),
                            sessionStartedAt: snapshot.startedAt,
                            locale: snapshot.locale,
                            unit: snapshot.unit,
                            weightIncrement: snapshot.weightIncrement,
                            onLogSet: { weightKg, reps in
                                let setNumber = exercise.completedSets.count + 1
                                onLogSet(exercise.exerciseId, setNumber, weightKg, reps)
                            }
                        )
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .onAppear {
            selectedPage = snapshot.currentExerciseIndex.clamped(to: 0..<max(1, snapshot.exercises.count))
        }
    }

    private func nextName(after index: Int) -> String? {
        let next = index + 1
        guard next < snapshot.exercises.count else { return nil }
        return snapshot.exercises[next].name
    }
}

private extension Int {
    func clamped(to range: Range<Int>) -> Int {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound - 1)
    }
}
```

**Step 3: Verify build**

Build the WatchOS target. `TimedExerciseView` will produce a build error since it doesn't exist yet — create a stub placeholder:

```swift
// Temporary stub — replaced in Task 6
struct TimedExerciseView: View {
    let exercise: WatchExercise
    let exerciseIndex: Int
    let totalExercises: Int
    let nextExerciseName: String?
    let sessionStartedAt: String
    let locale: String
    let onLogTimedSet: (Int) -> Void

    var body: some View {
        Text("Timed: \(exercise.name)")
    }
}
```

Put the stub in `ios/StrengthAppWatch/Views/TimedExerciseView.swift`.

Expected: Builds successfully.

**Step 4: Commit**

```bash
git add ios/StrengthAppWatch/Views/
git commit -m "feat: add WatchOS strength exercise page UI with Digital Crown, rest timer, and haptics"
```

---

### Task 6: Build the WatchOS timed exercise view

**Files:**
- Modify: `ios/StrengthAppWatch/Views/TimedExerciseView.swift` (replace stub)

**Step 1: Replace TimedExerciseView stub with full implementation**

```swift
// ios/StrengthAppWatch/Views/TimedExerciseView.swift
import SwiftUI
import WatchKit

struct TimedExerciseView: View {
    let exercise: WatchExercise
    let exerciseIndex: Int
    let totalExercises: Int
    let nextExerciseName: String?
    let sessionStartedAt: String
    let locale: String
    let onLogTimedSet: (Int) -> Void

    @State private var isRunning: Bool = false
    @State private var elapsed: Int = 0
    @State private var timer: Timer? = nil
    @State private var restTimerStart: Date? = nil
    @State private var restRemaining: Int = 0
    @State private var restTimer: Timer? = nil

    private var targetDuration: Int {
        exercise.targetDurationSeconds ?? 60
    }

    private var remaining: Int {
        max(0, targetDuration - elapsed)
    }

    private var nextSetNumber: Int {
        exercise.completedSets.count + 1
    }

    private var allSetsComplete: Bool {
        exercise.completedSets.count >= exercise.targetSets
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Rest timer pill
                if let _ = restTimerStart, restRemaining > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        Text("\(WatchL10n.string("resting", locale: locale)): \(formatTime(restRemaining))")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(12)
                }

                // Set progress
                Text(WatchL10n.setOf(min(nextSetNumber, exercise.targetSets), exercise.targetSets, locale: locale))
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Exercise name
                Text(exercise.name)
                    .font(.headline)
                    .bold()
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Countdown display
                Text(formatTime(isRunning ? remaining : targetDuration))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(isRunning ? .blue : .primary)

                // START / STOP button
                if !allSetsComplete {
                    Button(action: toggleTimer) {
                        Text(isRunning
                             ? WatchL10n.string("stop", locale: locale)
                             : WatchL10n.string("start", locale: locale))
                            .font(.headline)
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isRunning ? .red : .blue)
                } else {
                    Text("✓")
                        .font(.title2)
                        .foregroundColor(.green)
                }

                // Next exercise + session time
                HStack {
                    if let next = nextExerciseName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WatchL10n.string("next", locale: locale))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(next)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(WatchL10n.string("session", locale: locale))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(elapsedSessionTime())
                            .font(.caption2)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Timer

    private func toggleTimer() {
        if isRunning {
            // STOP tapped early — log partial duration
            timer?.invalidate()
            timer = nil
            isRunning = false
            let duration = elapsed
            elapsed = 0
            logCompleted(duration: duration)
        } else {
            // START
            elapsed = 0
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                DispatchQueue.main.async {
                    elapsed += 1
                    let rem = targetDuration - elapsed
                    // Haptic at 3, 2, 1
                    if rem == 3 || rem == 2 || rem == 1 {
                        WKInterfaceDevice.current().play(.click)
                    }
                    if rem <= 0 {
                        // Auto-log
                        timer?.invalidate()
                        timer = nil
                        isRunning = false
                        WKInterfaceDevice.current().play(.notification)
                        let duration = elapsed
                        elapsed = 0
                        logCompleted(duration: duration)
                    }
                }
            }
        }
    }

    private func logCompleted(duration: Int) {
        onLogTimedSet(duration)

        // Start rest timer
        restTimerStart = Date()
        restRemaining = exercise.restSeconds
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let elapsedRest = Int(Date().timeIntervalSince(restTimerStart ?? Date()))
            let rem = exercise.restSeconds - elapsedRest
            DispatchQueue.main.async {
                restRemaining = max(0, rem)
                if rem == 3 || rem == 2 || rem == 1 {
                    WKInterfaceDevice.current().play(.click)
                }
                if rem <= 0 {
                    restTimer?.invalidate()
                    restTimer = nil
                    restTimerStart = nil
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func elapsedSessionTime() -> String {
        let formatter = ISO8601DateFormatter()
        guard let start = formatter.date(from: sessionStartedAt) else { return "0:00" }
        let elapsed = Int(Date().timeIntervalSince(start))
        return formatTime(elapsed)
    }
}
```

**Step 2: Verify build**

Build the WatchOS target.

Expected: Builds successfully.

**Step 3: Commit**

```bash
git add ios/StrengthAppWatch/Views/TimedExerciseView.swift
git commit -m "feat: add WatchOS timed exercise view with countdown, auto-log, and haptics"
```

---

### Task 7: Build the WatchOS main ContentView with all states

**Files:**
- Modify: `ios/StrengthAppWatch/ContentView.swift`

**Step 1: Replace ContentView with full state machine**

This view handles: idle (no session), active workout (exercise pages with force-sync pull-down), workout complete, disconnected indicator, and sync failure toast.

```swift
// ios/StrengthAppWatch/ContentView.swift
import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject var sessionManager: WorkoutSessionManager

    var body: some View {
        ZStack {
            if sessionManager.showWorkoutComplete {
                workoutCompleteView
            } else if let snapshot = sessionManager.snapshot {
                activeWorkoutView(snapshot: snapshot)
            } else {
                idleView
            }

            // Disconnected indicator
            if !sessionManager.isConnected && sessionManager.snapshot != nil {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(6)
                    }
                    Spacer()
                }
            }

            // Sync failed toast
            if sessionManager.syncFailed {
                VStack {
                    Spacer()
                    Text(WatchL10n.string("sync_failed", locale: sessionManager.snapshot?.locale ?? "en"))
                        .font(.caption2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 12) {
            Text("StrengthApp")
                .font(.headline)
            Text(WatchL10n.string("no_active_workout", locale: "en"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text(WatchL10n.string("start_on_iphone", locale: "en"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Active workout

    private func activeWorkoutView(snapshot: SessionSnapshot) -> some View {
        ExercisePageView(
            snapshot: snapshot,
            onLogSet: { exerciseId, setNumber, weightKg, reps in
                let message = LogSetMessage.strength(
                    exerciseId: exerciseId,
                    setNumber: setNumber,
                    weightKg: weightKg,
                    reps: reps
                )
                sessionManager.sendLogSet(message)
            },
            onLogTimedSet: { exerciseId, setNumber, durationSeconds in
                let message = LogSetMessage.timed(
                    exerciseId: exerciseId,
                    setNumber: setNumber,
                    durationSeconds: durationSeconds
                )
                sessionManager.sendLogSet(message)
            }
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { sessionManager.forceSync() }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Workout complete

    private var workoutCompleteView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text(WatchL10n.string("workout_complete", locale: sessionManager.snapshot?.locale ?? "en"))
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
```

**Step 2: Verify build**

Build the WatchOS target.

Expected: Builds successfully.

**Step 3: Commit**

```bash
git add ios/StrengthAppWatch/ContentView.swift
git commit -m "feat: add WatchOS ContentView with idle, active, complete, and error states"
```

---

### Task 8: Create the iOS-side WatchSessionManager (WCSession bridge)

**Files:**
- Create: `ios/Runner/WatchSessionManager.swift`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/Runner-Bridging-Header.h` (may need update)

**Step 1: Create WatchSessionManager.swift**

This Swift class runs on the iOS side. It:
- Activates `WCSession` and acts as its delegate
- Receives `log_set` / `log_timed_set` messages from the Watch and forwards them to Flutter via MethodChannel
- Receives session snapshots from Flutter via MethodChannel and sends them to the Watch via `updateApplicationContext` (or `sendMessage` if reachable)

```swift
// ios/Runner/WatchSessionManager.swift
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

        // Try direct message if reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Direct send to Watch failed: \(error), using application context")
                // Fall back to application context
                try? session.updateApplicationContext(message)
            }
        } else {
            // Use application context (delivered when Watch wakes)
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("Failed to update application context: \(error)")
            }
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
```

**Step 2: Update AppDelegate.swift to configure the WatchSessionManager**

```swift
// ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        // Configure Watch connectivity bridge
        if let controller = window?.rootViewController as? FlutterViewController {
            WatchSessionManager.shared.configure(with: controller)
        }
    }
}
```

**Step 3: Verify build**

Build the iOS target (Runner scheme). You may need to add `WatchConnectivity.framework` to the iOS target's linked frameworks.

Expected: Builds successfully.

**Step 4: Commit**

```bash
git add ios/Runner/WatchSessionManager.swift ios/Runner/AppDelegate.swift
git commit -m "feat: add iOS WatchSessionManager bridging MethodChannel to WCSession"
```

---

### Task 9: Create the Dart WatchSyncService

**Files:**
- Create: `lib/src/features/watch/watch_sync_service.dart`

**Step 1: Create WatchSyncService**

This service runs on the Flutter side. It:
- Listens to `AppStateController` state changes
- Builds session snapshot JSON payloads from the current `AppState`
- Sends them to the iOS side via `MethodChannel`
- Listens for `log_set` / `log_timed_set` events from the Watch via `EventChannel`
- Processes them through `WorkoutController`

```dart
// lib/src/features/watch/watch_sync_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';
import 'package:strength_training_tracker/src/l10n/exercise_translations.dart';

final watchSyncServiceProvider = Provider<WatchSyncService>((ref) {
  return WatchSyncService(ref);
});

class WatchSyncService {
  WatchSyncService(this._ref);

  final Ref _ref;

  static const _methodChannel = MethodChannel('com.strengthapp/watch');
  static const _eventChannel = EventChannel('com.strengthapp/watch_events');

  StreamSubscription<dynamic>? _eventSubscription;
  bool _isListening = false;
  String? _lastSentSessionId;

  /// Start listening for state changes and Watch events.
  /// Call this once during app initialization.
  void initialize() {
    if (_isListening) return;
    _isListening = true;

    // Listen for Watch → Phone messages
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleWatchEvent,
      onError: (error) {
        debugPrint('Watch event stream error: $error');
      },
    );

    // Listen for state changes and push to Watch
    _ref.listen<AppState>(
      appStateControllerProvider,
      (previous, next) {
        _onStateChanged(next);
      },
    );

    // Send initial state if there's an active session
    final state = _ref.read(appStateControllerProvider);
    _onStateChanged(state);
  }

  void dispose() {
    _eventSubscription?.cancel();
    _isListening = false;
  }

  // MARK: - State → Watch

  void _onStateChanged(AppState state) {
    final session = state.activeSession;
    if (session == null) {
      // If we previously had a session, send session_end
      if (_lastSentSessionId != null) {
        _sendSessionEnd();
        _lastSentSessionId = null;
      }
      return;
    }

    _lastSentSessionId = session.id;

    final routine = state.routineById(session.routineId);
    if (routine == null) return;

    final snapshot = _buildSessionSnapshot(state, session, routine);
    _sendSessionUpdate(snapshot);
  }

  Map<String, dynamic> _buildSessionSnapshot(
    AppState state,
    WorkoutSession session,
    Routine routine,
  ) {
    final locale = state.preferredLanguage.isNotEmpty
        ? state.preferredLanguage
        : 'en';
    final unit = state.preferredUnit;
    final weightIncrement = unit == 'lbs' ? 5.0 : 2.5;

    final exercises = routine.exercises.map((re) {
      final exercise = state.exerciseById(re.exerciseId);
      final name = exercise != null
          ? _localizedExerciseName(exercise, locale)
          : 'Unknown';
      final completedSets = session.completedSets
          .where((s) => s.exerciseId == re.exerciseId)
          .toList()
        ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

      return {
        'exerciseId': re.exerciseId,
        'name': name,
        'exerciseType': exercise?.exerciseType ?? 'strength',
        'targetSets': re.targetSets,
        'targetReps': re.targetReps,
        'targetDurationSeconds': re.targetDurationSeconds,
        'restSeconds': re.restSeconds,
        'recommendedWeightKg': re.recommendedWeightKg,
        'completedSets': completedSets.map((s) => {
          'setNumber': s.setNumber,
          'weightKg': s.weightKg,
          'reps': s.reps,
          'durationSeconds': s.durationSeconds,
          'completedAt': s.completedAt.toIso8601String(),
        }).toList(),
      };
    }).toList();

    return {
      'type': 'session_update',
      'session': {
        'routineId': session.routineId,
        'routineName': routine.name,
        'startedAt': session.startedAt.toIso8601String(),
        'currentExerciseIndex': session.currentExerciseIndex,
        'exercises': exercises,
      },
      'locale': locale,
      'unit': unit,
      'weightIncrement': weightIncrement,
    };
  }

  String _localizedExerciseName(Exercise exercise, String locale) {
    if (exercise.translationKey != null && exercise.translationKey!.isNotEmpty) {
      final translated = ExerciseTranslations.translate(
        exercise.translationKey!,
        locale,
      );
      if (translated != exercise.translationKey) return translated;
    }
    return exercise.name;
  }

  Future<void> _sendSessionUpdate(Map<String, dynamic> snapshot) async {
    try {
      await _methodChannel.invokeMethod('sendSessionUpdate', snapshot);
    } catch (e) {
      debugPrint('Failed to send session update to Watch: $e');
    }
  }

  Future<void> _sendSessionEnd() async {
    try {
      await _methodChannel.invokeMethod('sendSessionEnd');
    } catch (e) {
      debugPrint('Failed to send session end to Watch: $e');
    }
  }

  // MARK: - Watch → State

  void _handleWatchEvent(dynamic event) {
    if (event is! Map) return;
    final data = Map<String, dynamic>.from(event as Map);
    final type = data['type'] as String?;

    switch (type) {
      case 'log_set':
        _handleLogSet(data);
      case 'log_timed_set':
        _handleLogTimedSet(data);
      case 'request_sync':
        _handleSyncRequest();
      default:
        debugPrint('Unknown Watch event type: $type');
    }
  }

  void _handleLogSet(Map<String, dynamic> data) {
    final exerciseId = data['exerciseId'] as String?;
    final setNumber = data['setNumber'] as int?;
    final weightKg = (data['weightKg'] as num?)?.toDouble();
    final reps = data['reps'] as int?;

    if (exerciseId == null || setNumber == null || weightKg == null || reps == null) {
      debugPrint('Invalid log_set data from Watch: $data');
      return;
    }

    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;

    // Duplicate detection: check if this exerciseId + setNumber already exists
    final existingSet = session.completedSets.any(
      (s) => s.exerciseId == exerciseId && s.setNumber == setNumber,
    );
    if (existingSet) {
      debugPrint('Duplicate set from Watch ignored: $exerciseId set $setNumber');
      return;
    }

    // Navigate to the exercise if needed
    final routine = state.routineById(session.routineId);
    if (routine != null) {
      final exerciseIndex = routine.exercises
          .indexWhere((e) => e.exerciseId == exerciseId);
      if (exerciseIndex >= 0 && exerciseIndex != session.currentExerciseIndex) {
        _ref.read(workoutControllerProvider).goToExercise(exerciseIndex);
      }
    }

    // Log the set via WorkoutController
    _ref.read(workoutControllerProvider).logSet(
      weightKg: weightKg,
      reps: reps,
    );
  }

  void _handleLogTimedSet(Map<String, dynamic> data) {
    final exerciseId = data['exerciseId'] as String?;
    final setNumber = data['setNumber'] as int?;
    final durationSeconds = data['durationSeconds'] as int?;

    if (exerciseId == null || setNumber == null || durationSeconds == null) {
      debugPrint('Invalid log_timed_set data from Watch: $data');
      return;
    }

    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;

    // Duplicate detection
    final existingSet = session.completedSets.any(
      (s) => s.exerciseId == exerciseId && s.setNumber == setNumber,
    );
    if (existingSet) {
      debugPrint('Duplicate timed set from Watch ignored: $exerciseId set $setNumber');
      return;
    }

    // Navigate to the exercise if needed
    final routine = state.routineById(session.routineId);
    if (routine != null) {
      final exerciseIndex = routine.exercises
          .indexWhere((e) => e.exerciseId == exerciseId);
      if (exerciseIndex >= 0 && exerciseIndex != session.currentExerciseIndex) {
        _ref.read(workoutControllerProvider).goToExercise(exerciseIndex);
      }
    }

    // Log the timed set
    _ref.read(workoutControllerProvider).logTimedSet(
      durationSeconds: durationSeconds,
    );
  }

  void _handleSyncRequest() {
    // Re-send current state to Watch
    final state = _ref.read(appStateControllerProvider);
    _onStateChanged(state);
  }

  // MARK: - Query methods

  Future<bool> isWatchPaired() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isWatchPaired');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isWatchReachable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isWatchReachable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
```

**Step 2: Verify**

Run: `flutter analyze`

Expected: No issues. (Note: on web platform, the MethodChannel calls will fail gracefully — the service only activates on iOS.)

**Step 3: Commit**

```bash
git add lib/src/features/watch/watch_sync_service.dart
git commit -m "feat: add Dart WatchSyncService with MethodChannel bridge and state sync"
```

---

### Task 10: Initialize WatchSyncService in main.dart

**Files:**
- Modify: `lib/main.dart`

**Step 1: Import and initialize the WatchSyncService**

The WatchSyncService should only be initialized on iOS (not web). Add the initialization after the `ProviderScope` is created but before `runApp`, or inside the app widget's initialization.

Since Riverpod providers need a `ProviderContainer` or widget context, the cleanest approach is to create a wrapper widget that initializes the service.

Create the initialization inside `main.dart` by reading the provider after the container is set up:

Add to `lib/main.dart`, at the top with other imports:

```dart
import 'dart:io' show Platform;
import 'package:strength_training_tracker/src/features/watch/watch_sync_service.dart';
```

Then, replace the `runApp(ProviderScope(...))` block with:

```dart
  final container = ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(repository),
      initialAppStateProvider.overrideWithValue(initialState),
    ],
  );

  // Initialize Watch sync on iOS only
  if (!kIsWeb) {
    try {
      container.read(watchSyncServiceProvider).initialize();
    } catch (e) {
      debugPrint('Watch sync initialization failed: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StrengthTrainingApp(),
    ),
  );
```

Do the same for the `catch` fallback branch (SharedPreferences path) so both code paths initialize the Watch sync.

Note: `dart:io` is not available on web, so guard the import:

Instead of importing `dart:io`, just use `kIsWeb` from `package:flutter/foundation.dart` (already imported). The Watch sync service itself handles the platform check gracefully since MethodChannel calls will fail silently on unsupported platforms.

**Step 2: Verify**

Run: `flutter analyze`

Expected: No issues.

**Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize WatchSyncService on iOS at app startup"
```

---

### Task 11: Add WatchConnectivity entitlement and App Group

**Files:**
- Modify: `ios/Runner/Runner.entitlements` (create if needed)
- Modify: `ios/StrengthAppWatch/StrengthAppWatch.entitlements` (create if needed)
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (via Xcode)

**Step 1: Enable Watch Connectivity and App Groups in Xcode**

Open `ios/Runner.xcworkspace` in Xcode.

For the **Runner** (iOS) target:
1. Select Runner target → Signing & Capabilities
2. Click "+" → Add "App Groups"
3. Add group: `group.com.strengthapp.shared` (use your actual bundle ID prefix)

For the **StrengthAppWatch** target:
1. Select StrengthAppWatch target → Signing & Capabilities
2. Click "+" → Add "App Groups"
3. Add the same group: `group.com.strengthapp.shared`

Xcode will create/update `.entitlements` files for both targets.

**Step 2: Verify**

Build both targets in Xcode.

Expected: Both build successfully with entitlements configured.

**Step 3: Commit**

```bash
git add ios/Runner/Runner.entitlements ios/StrengthAppWatch/StrengthAppWatch.entitlements ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: add App Groups entitlement for Watch Connectivity"
```

---

### Task 12: Add Watch status indicator to active workout screen

**Files:**
- Modify: `lib/src/features/workout/active_workout_screen.dart`

**Step 1: Add Watch connectivity status to the AppBar**

In the active workout screen, add a small Watch icon in the app bar that shows whether a Watch is connected. This uses the `WatchSyncService` to query reachability.

At the top of `_ActiveWorkoutScreenState`, add a field for Watch status:

```dart
bool _watchReachable = false;
```

In `initState`, add a periodic check (every 5 seconds) on iOS:

```dart
// In initState, after existing setup:
if (!kIsWeb) {
  _checkWatchStatus();
}
```

Add the method:

```dart
Future<void> _checkWatchStatus() async {
  if (!mounted) return;
  try {
    final service = ref.read(watchSyncServiceProvider);
    final reachable = await service.isWatchReachable();
    if (mounted) {
      setState(() => _watchReachable = reachable);
    }
  } catch (_) {}
  // Check again in 5 seconds
  Future.delayed(const Duration(seconds: 5), () {
    if (mounted) _checkWatchStatus();
  });
}
```

Add the import at the top:

```dart
import 'package:strength_training_tracker/src/features/watch/watch_sync_service.dart';
```

In the AppBar's `actions` list, add a Watch icon (before any existing actions):

```dart
if (!kIsWeb && _watchReachable)
  Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Icon(
      Icons.watch,
      size: 18,
      color: AppTheme.primary,
    ),
  ),
```

**Step 2: Verify**

Run: `flutter analyze`

Expected: No issues.

**Step 3: Commit**

```bash
git add lib/src/features/workout/active_workout_screen.dart
git commit -m "feat: add Watch connectivity indicator to active workout screen"
```

---

### Task 13: Handle weight unit conversion in Watch communication

**Files:**
- Modify: `lib/src/features/watch/watch_sync_service.dart`

**Step 1: Ensure weights are always sent in kg internally**

The design specifies that `weightKg` in the JSON is always in kg. The Watch receives the user's preferred `unit` and `weightIncrement` to display and adjust values in the user's unit, but converts back to kg before sending `log_set`.

Review the `_buildSessionSnapshot` method — it already sends `recommendedWeightKg` and `completedSets[].weightKg` which are stored in kg in `AppState`. Confirm the `unit` field is passed correctly.

In the `_handleLogSet` method, the Watch sends `weightKg` already in kg (the Watch-side `StrengthExerciseView` stores and sends the raw kg value, displaying the converted value). This is correct.

However, we need to verify the Watch-side `StrengthExerciseView` stores weight in kg internally. Looking at the Watch code from Task 5, `weight` is initialized from `recommendedWeightKg` (which is in kg) and the Digital Crown adjusts by `weightIncrement`. The increment should be in the display unit.

**Update StrengthExerciseView** in `ios/StrengthAppWatch/Views/StrengthExerciseView.swift`:

The `weight` state variable should store kg internally. When `unit` is "lbs", the Crown should adjust in lbs but the stored value must be converted back to kg for the `onLogSet` callback.

Update the `weight` handling:

```swift
// In StrengthExerciseView, change the weight property to store display units
// and convert on log:

// The prefill already uses kg values from the snapshot.
// For lbs display: convert kg → lbs for display, then lbs → kg on log.

private var displayWeight: Double {
    get { unit == "lbs" ? weight * 2.20462 : weight }
}
```

Actually, the simpler approach (matching the design doc): store weight in kg internally, but make the Crown step in the correct unit's increment. The `formatWeight` function already handles display conversion.

The current Crown rotation binding directly modifies `weight` by `weightIncrement`. If unit is "lbs" and increment is 5, the Crown adds 5 to the kg value, which is wrong. Fix: when unit is "lbs", the increment should be in lbs, so convert the step to kg.

Update the Digital Crown rotation `by` parameter:

```swift
by: editingWeight
    ? (unit == "lbs" ? weightIncrement / 2.20462 : weightIncrement)
    : 1,
```

And update `prefillValues` — the values from the snapshot are already in kg, so no change needed there.

**Step 2: Verify build**

Build the WatchOS target.

Expected: Builds successfully.

**Step 3: Commit**

```bash
git add ios/StrengthAppWatch/Views/StrengthExerciseView.swift lib/src/features/watch/watch_sync_service.dart
git commit -m "fix: ensure Watch Digital Crown increments correctly for lbs unit"
```

---

### Task 14: Add platform guard for web compatibility

**Files:**
- Modify: `lib/src/features/watch/watch_sync_service.dart`

**Step 1: Add platform guards**

The `MethodChannel` and `EventChannel` calls will throw on web. Add guards so the service is a no-op on non-iOS platforms.

Add at the top of `WatchSyncService.initialize()`:

```dart
void initialize() {
  if (kIsWeb) return; // Watch sync only works on iOS
  if (_isListening) return;
  // ... rest of method
}
```

Add the same guard to `isWatchPaired()` and `isWatchReachable()`:

```dart
Future<bool> isWatchPaired() async {
  if (kIsWeb) return false;
  // ...
}

Future<bool> isWatchReachable() async {
  if (kIsWeb) return false;
  // ...
}
```

Add import if not present:

```dart
import 'package:flutter/foundation.dart';
```

**Step 2: Verify**

Run: `flutter analyze`

Expected: No issues.

**Step 3: Commit**

```bash
git add lib/src/features/watch/watch_sync_service.dart
git commit -m "fix: add web platform guards to WatchSyncService"
```

---

### Task 15: Add Watch app icon assets

**Files:**
- Create: `ios/StrengthAppWatch/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: Watch app icon images (various sizes)

**Step 1: Configure Watch app icon in Xcode**

Open `ios/Runner.xcworkspace` in Xcode. Select the `StrengthAppWatch` target.

In the asset catalog (`Assets.xcassets`), Xcode should have generated an `AppIcon` image set. The Watch requires icons at these sizes:
- 40x40 (Notification Center, 38mm)
- 44x44 (Notification Center, 42mm)
- 48x48 (Notification Center, 44mm/45mm)
- 54x54 (Notification Center, 49mm)
- 58x58 (Companion Settings, 2x)
- 66x66 (Short Look, 38mm/42mm)
- 80x80 (Home Screen, 38mm)
- 87x87 (Companion Settings, 3x)
- 88x88 (Home Screen, 42mm)
- 92x92 (Short Look, 44mm/45mm)
- 100x100 (Home Screen, 44mm)
- 102x102 (Short Look, 49mm)
- 108x108 (Home Screen, 45mm)
- 117x117 (Home Screen, 49mm)
- 196x196 (Short Look, large)
- 216x216 (Short Look, 49mm large)
- 1024x1024 (App Store)

Use the existing iOS app icon (`assets/icon/app_icon.png`) as the source, resized to each required dimension.

**Step 2: Generate icons**

If `flutter_launcher_icons` supports Watch targets, configure it. Otherwise, resize manually or use a tool like `watchos-icon-generator`.

The simplest approach: use the existing 1024x1024 icon and resize to each required dimension using `sips` (built into macOS):

```bash
cd ios/StrengthAppWatch/Assets.xcassets/AppIcon.appiconset
for size in 40 44 48 54 58 66 80 87 88 92 100 102 108 117 196 216 1024; do
  sips -z $size $size ../../../../assets/icon/app_icon.png --out icon_${size}.png
done
```

Then update `Contents.json` to reference each generated file. (Xcode can do this via drag-and-drop into the asset catalog.)

**Step 3: Verify build**

Build the WatchOS target.

Expected: Builds successfully with app icon visible in Watch simulator.

**Step 4: Commit**

```bash
git add ios/StrengthAppWatch/Assets.xcassets/
git commit -m "feat: add Watch app icon assets"
```

---

### Task 16: Configure Xcode project deployment targets and schemes

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (via Xcode)

**Step 1: Verify deployment targets**

Open `ios/Runner.xcworkspace` in Xcode.

- **Runner** (iOS) target: Ensure minimum deployment target is iOS 15.0+
- **StrengthAppWatch** target: Ensure minimum deployment target is watchOS 8.0+

**Step 2: Verify the Watch app is embedded in the iOS app**

In Xcode, select Runner target → General → "Frameworks, Libraries, and Embedded Content" (or Build Phases → "Embed Watch Content"). Verify that `StrengthAppWatch.app` is listed and set to "Embed & Sign".

If not present, add it:
- Build Phases → "+" → "New Copy Files Phase"
- Destination: "Watch Content V2"
- Add `StrengthAppWatch.app`

**Step 3: Verify both targets build**

Build the Runner (iOS) scheme — it should also build and embed the WatchOS app.

Expected: Both targets build and the Watch app is embedded in the iOS app bundle.

**Step 4: Commit**

```bash
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "chore: configure Xcode deployment targets and Watch app embedding"
```

---

### Task 17: End-to-end verification

**Step 1: Run Flutter analyze**

Run: `flutter analyze`

Expected: No issues.

**Step 2: Run Flutter tests**

Run: `flutter test`

Expected: All existing tests pass. The WatchSyncService uses MethodChannel which won't be available in tests, but since it's guarded by `kIsWeb` checks and only initialized in `main.dart`, tests should not be affected.

**Step 3: Build iOS app with Watch extension**

Run: `flutter build ios --debug` (or build from Xcode with Runner scheme targeting a physical device or simulator)

Expected: Builds successfully. The `.app` bundle should contain the Watch app.

**Step 4: Test on physical devices (requires Apple Watch + paired iPhone)**

1. Install the iOS app on a paired iPhone
2. The Watch app should appear automatically in the Watch app on the iPhone
3. Start a workout on the iPhone
4. The Watch should wake and display the workout exercises
5. Swipe between exercises, adjust weight/reps with Digital Crown, log a set
6. Verify the logged set appears on the iPhone
7. End the workout on the iPhone — Watch should show "Workout Complete" for 3 seconds
8. Test offline: put iPhone in Airplane Mode, log sets on Watch, then restore connection
9. Verify queued sets are synced to the iPhone

**Step 5: Test timed exercises**

1. Create a routine with a timed exercise (e.g., Plank Hold)
2. Start the workout, navigate to the timed exercise on the Watch
3. Tap START, verify countdown runs
4. Let it reach 0 — verify auto-log and haptic buzz
5. Start another set, tap STOP early — verify partial duration is logged

**Step 6: Test localization**

1. Set the app language to French in app settings
2. Start a workout, check the Watch displays French strings ("SERIE", "VALIDER", "SUIVANT", etc.)
3. Verify exercise names are in French (from the phone's translation system)

**Step 7: Final commit**

```bash
git add -A
git commit -m "feat: Apple Watch companion app — end-to-end verified"
```
