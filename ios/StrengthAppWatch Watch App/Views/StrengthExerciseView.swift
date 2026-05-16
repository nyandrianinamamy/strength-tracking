import SwiftUI

struct StrengthExerciseView: View {
    let exercise: WatchExercise
    let exerciseIndex: Int
    let totalExercises: Int
    let nextExerciseName: String?
    let sessionStartedAt: String
    let activeRest: WatchRestState?
    let activeRestRemaining: Int
    let locale: String
    let unit: String

    private var nextSetNumber: Int {
        min(exercise.completedSets.count + 1, exercise.targetSets)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                header(sessionTime: elapsedSessionTime(now: context.date))

                if activeRestRemaining > 0 {
                    restPill
                        .padding(.top, 3)
                }

                Spacer().frame(height: activeRestRemaining > 0 ? 5 : 10)

                Text(WatchL10n.setOf(nextSetNumber, exercise.targetSets, locale: locale))
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundColor(Color(white: 0.63))

                Text(exercise.name)
                    .font(.system(size: 18, weight: .black))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 2)

                Spacer().frame(height: 7)

                VStack(spacing: 6) {
                    StrengthInfoRow(label: "Target", value: "\(exercise.targetReps) reps / \(exercise.restSeconds)s rest")
                    StrengthInfoRow(label: "Last", value: lastSetText)
                    if exercise.suggestedWeightKg > 0 {
                        StrengthInfoRow(label: "Next", value: formatWeight(exercise.suggestedWeightKg, unit: unit))
                    }
                }

                Spacer(minLength: 4)
                footer
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }

    private func header(sessionTime: String) -> some View {
        HStack {
            Text(sessionTime)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .monospacedDigit()
            Spacer()
            Text("\(exerciseIndex + 1)/\(totalExercises)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.63))
        }
        .padding(.top, 4)
    }

    private var restPill: some View {
        HStack {
            Spacer(minLength: 0)
            Text("Rest \(formatTime(activeRestRemaining))")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.12))
        .cornerRadius(7)
        .foregroundColor(.blue)
    }

    private var lastSetText: String {
        guard let lastSet = exercise.completedSets.last else { return "-" }
        return "\(formatWeight(lastSet.weightKg, unit: unit)) x \(lastSet.reps)"
    }

    private var footer: some View {
        HStack {
            if let nextExerciseName {
                VStack(alignment: .leading, spacing: 1) {
                    Text(WatchL10n.string("next", locale: locale))
                        .font(.system(size: 8, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(Color(white: 0.63))
                    Text(nextExerciseName)
                        .font(.system(size: 10, weight: .black))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    private func elapsedSessionTime(now: Date) -> String {
        guard let start = parseISO8601(sessionStartedAt) else { return "0:00" }
        return formatTime(max(0, Int(now.timeIntervalSince(start))))
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func formatWeight(_ kg: Double, unit: String) -> String {
        let value = unit == "lbs" ? kg * 2.20462 : kg
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(unit)"
        }
        return String(format: "%.1f %@", value, unit)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

private struct StrengthInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(white: 0.63))
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 11, weight: .black))
                .lineLimit(1)
        }
    }
}
