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
                    by: editingWeight
                        ? (unit == "lbs" ? weightIncrement / 2.20462 : weightIncrement)
                        : 1,
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
            weight = lastSet.weightKg
            reps = exercise.targetReps
        } else {
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
