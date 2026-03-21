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
    @State private var lastRestAlertSecond: Int? = nil

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
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(elapsedSessionTime(now: context.date))
                                .font(.caption2)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            restTimer?.invalidate()
            restTimer = nil
            restTimerStart = nil
            lastRestAlertSecond = nil
            isRunning = false
        }
        .onAppear { restoreRestTimer() }
        .onChange(of: exercise.completedSets.count) { _ in restoreRestTimer() }
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
        startRestTimer(from: Date())
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func elapsedSessionTime(now: Date) -> String {
        guard let start = parseISO8601(sessionStartedAt) else { return "0:00" }
        let elapsed = Int(now.timeIntervalSince(start))
        return formatTime(elapsed)
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func restoreRestTimer() {
        guard let lastSet = exercise.completedSets.last,
              let completedAt = parseISO8601(lastSet.completedAt) else {
            restTimer?.invalidate()
            restTimer = nil
            restTimerStart = nil
            restRemaining = 0
            lastRestAlertSecond = nil
            return
        }

        let elapsedRest = Int(Date().timeIntervalSince(completedAt))
        let remaining = max(0, exercise.restSeconds - elapsedRest)
        guard remaining > 0 else {
            restTimer?.invalidate()
            restTimer = nil
            restTimerStart = nil
            restRemaining = 0
            lastRestAlertSecond = nil
            return
        }

        startRestTimer(from: completedAt)
    }

    private func startRestTimer(from start: Date) {
        restTimer?.invalidate()
        restTimerStart = start
        lastRestAlertSecond = nil
        updateRestRemaining()

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                updateRestRemaining()
            }
        }
    }

    private func updateRestRemaining() {
        let start = restTimerStart ?? Date()
        let elapsedRest = Int(Date().timeIntervalSince(start))
        let remaining = max(0, exercise.restSeconds - elapsedRest)
        restRemaining = remaining

        if (remaining == 3 || remaining == 2 || remaining == 1) && lastRestAlertSecond != remaining {
            lastRestAlertSecond = remaining
            WKInterfaceDevice.current().play(.click)
        }

        if remaining <= 0 {
            WKInterfaceDevice.current().play(.notification)
            restTimer?.invalidate()
            restTimer = nil
            restTimerStart = nil
            lastRestAlertSecond = nil
        }
    }
}
