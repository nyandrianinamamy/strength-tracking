import SwiftUI

struct TimedExerciseView: View {
    let exercise: WatchExercise
    let exerciseIndex: Int
    let totalExercises: Int
    let nextExerciseName: String?
    let sessionStartedAt: String
    let activeRestRemaining: Int
    let locale: String

    private var targetDuration: Int {
        exercise.targetDurationSeconds ?? 60
    }

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

                Text(WorkoutStrings.setOf(nextSetNumber, exercise.targetSets, locale: locale))
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundColor(Color(white: 0.63))

                Text(exercise.name)
                    .font(.system(size: 18, weight: .black))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 2)

                Spacer().frame(height: 7)

                Text(formatTime(activeTimedRemaining(now: context.date) ?? targetDuration))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(activeTimedRemaining(now: context.date) == nil ? .primary : .blue)

                VStack(spacing: 6) {
                    TimedInfoRow(label: WorkoutStrings.string("target", locale: locale), value: targetText)
                    TimedInfoRow(label: WorkoutStrings.string("last", locale: locale), value: lastSetText)
                }
                .padding(.top, 6)

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

    private var targetText: String {
        if exercise.restSeconds <= 0 {
            return formatDurationLabel(targetDuration)
        }

        return "\(formatDurationLabel(targetDuration)) / \(formatDurationLabel(exercise.restSeconds)) \(WorkoutStrings.string("rest", locale: locale))"
    }

    private var restPill: some View {
        HStack {
            Spacer(minLength: 0)
            Text("\(WorkoutStrings.string("rest", locale: locale)) \(formatTime(activeRestRemaining))")
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
        guard let lastSet = exercise.completedSets.last,
              let duration = lastSet.durationSeconds else { return "-" }
        return formatTime(duration)
    }

    private var footer: some View {
        HStack {
            if let nextExerciseName {
                VStack(alignment: .leading, spacing: 1) {
                    Text(WorkoutStrings.string("next", locale: locale))
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

    private func activeTimedRemaining(now: Date) -> Int? {
        guard let startRaw = exercise.activeTimerStartedAt,
              let start = parseISO8601(startRaw) else { return nil }
        return max(0, targetDuration - Int(now.timeIntervalSince(start)))
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

    private func formatDurationLabel(_ seconds: Int) -> String {
        if seconds >= 60, seconds % 60 == 0 {
            return "\(seconds / 60) min"
        }

        if seconds >= 60 {
            return formatTime(seconds)
        }

        return "\(seconds)s"
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

private struct TimedInfoRow: View {
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
