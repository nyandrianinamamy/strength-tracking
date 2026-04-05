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
    @State private var editingWeight: Bool = true
    @State private var lastRestAlertSecond: Int? = nil
    @State private var lastRestAlertSetCount: Int? = nil
    @FocusState private var crownFocused: Bool

    private var nextSetNumber: Int {
        exercise.completedSets.count + 1
    }

    private var allSetsComplete: Bool {
        exercise.completedSets.count >= exercise.targetSets
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let restInfo = computeRestRemaining(now: context.date)
            let sessionTime = elapsedSessionTime(now: context.date)
            let _ = playRestHapticsIfNeeded(remaining: restInfo.remaining, setCount: restInfo.setCount)

            VStack(spacing: 0) {
                Spacer().frame(height: 4)

                // Rest timer pill
                if restInfo.remaining > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10, weight: .black))
                        Text("\(WatchL10n.string("resting", locale: locale)): \(formatTime(restInfo.remaining))")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(999)
                }

                Spacer().frame(height: 8)

                // Set progress
                Text(WatchL10n.setOf(min(nextSetNumber, exercise.targetSets), exercise.targetSets, locale: locale))
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1)
                    .textCase(.uppercase)
                    .foregroundColor(Color(white: 0.63))

                // Exercise name
                Text(exercise.name)
                    .font(.system(size: 18, weight: .black))
                    .tracking(-0.45)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 2)

                Spacer().frame(height: 12)

                // Weight x Reps — large center stage display
                if !allSetsComplete {
                    HStack(alignment: .center, spacing: 8) {
                        Text(formatWeight(weight, unit: unit))
                            .font(.system(size: 24, weight: .black))
                            .tracking(-1.2)
                            .foregroundColor(editingWeight ? .blue : .blue.opacity(0.5))
                            .onTapGesture { editingWeight = true; crownFocused = true }

                        Text("x")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(white: 0.63))

                        Text("\(reps) \(WatchL10n.string("reps_short", locale: locale))")
                            .font(.system(size: 24, weight: .black))
                            .tracking(-1.2)
                            .foregroundColor(!editingWeight ? .primary : .primary.opacity(0.7))
                            .onTapGesture { editingWeight = false; crownFocused = true }
                    }
                    .focused($crownFocused)
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

                    Spacer()
                    Spacer().frame(height: 8)

                    // LOG SET button
                    Button(action: logSet) {
                        VStack(spacing: 1) {
                            Text(WatchL10n.string("log_set", locale: locale))
                                .font(.system(size: 13, weight: .black))
                                .tracking(-0.3)
                                .textCase(.uppercase)
                            Text(WatchL10n.string("confirm_weight_reps", locale: locale))
                                .font(.system(size: 8, weight: .bold))
                                .textCase(.uppercase)
                                .opacity(0.8)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Spacer()
                }

                // Footer — next exercise + session time
                Divider()
                    .padding(.top, 8)
                HStack {
                    if let next = nextExerciseName {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(WatchL10n.string("next", locale: locale))
                                .font(.system(size: 8, weight: .bold))
                                .textCase(.uppercase)
                                .foregroundColor(Color(white: 0.63))
                            Text(next)
                                .font(.system(size: 10, weight: .black))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(WatchL10n.string("session", locale: locale))
                            .font(.system(size: 8, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundColor(Color(white: 0.63))
                        Text(sessionTime)
                            .font(.system(size: 10, weight: .black))
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
                .padding(.horizontal, 4)
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
            weight = exercise.suggestedWeightKg
            reps = exercise.targetReps
        }
    }

    @discardableResult
    private func playRestHapticsIfNeeded(remaining: Int, setCount: Int) -> Bool {
        if setCount == 0 { return false }
        if lastRestAlertSetCount != setCount {
            lastRestAlertSetCount = setCount
            lastRestAlertSecond = remaining
            return false
        }
        guard lastRestAlertSecond != remaining else { return false }
        lastRestAlertSecond = remaining
        if remaining == 3 || remaining == 2 || remaining == 1 {
            WKInterfaceDevice.current().play(.click)
        } else if remaining == 0 {
            WKInterfaceDevice.current().play(.notification)
        }
        return true
    }

    /// Compute rest remaining from the last completed set's timestamp
    private func computeRestRemaining(now: Date) -> (remaining: Int, setCount: Int) {
        guard let lastSet = exercise.completedSets.last,
              let completedAt = parseISO8601(lastSet.completedAt) else {
            return (0, 0)
        }
        let elapsed = Int(now.timeIntervalSince(completedAt))
        let remaining = exercise.restSeconds - elapsed
        return (max(0, remaining), exercise.completedSets.count)
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

    private func logSet() {
        onLogSet(weight, reps)
        WKInterfaceDevice.current().play(.success)
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
}
