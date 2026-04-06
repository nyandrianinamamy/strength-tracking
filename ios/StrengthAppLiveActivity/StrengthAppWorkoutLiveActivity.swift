import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct StrengthAppWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StrengthLiveActivityAttributes.self) { context in
            WorkoutLiveActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.10, green: 0.14, blue: 0.24))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.currentExerciseProgressText)
                    } icon: {
                        Image(systemName: "figure.strengthtraining.traditional")
                    }
                    .font(.caption2.weight(.semibold))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .contentTransition(.identity)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.routineName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(context.state.currentExerciseName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.hasActiveRest ? "timer" : "checkmark.circle")
                            .foregroundColor(context.state.hasActiveRest ? .orange : .green)
                            .font(.caption)

                        if let restEndAt = context.state.restEndAt, context.state.hasActiveRest,
                           restEndAt > context.state.updatedAt {
                            Text("Rest:")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            Text(timerInterval: context.state.updatedAt...restEndAt, countsDown: true)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundColor(.white)
                        } else {
                            Text("Ready for next set")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.green)
                        }

                        Spacer()
                    }
                }
            } compactLeading: {
                Text("\(context.state.currentExerciseIndex)/\(context.state.totalExercises)")
                    .font(.caption2.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } compactTrailing: {
                if let restEndAt = context.state.restEndAt, context.state.hasActiveRest,
                   restEndAt > context.state.updatedAt {
                    Text(timerInterval: context.state.updatedAt...restEndAt, countsDown: true)
                        .monospacedDigit()
                        .font(.caption2.weight(.bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .frame(maxWidth: 48)
                        .contentTransition(.identity)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.caption2.weight(.bold))
                }
            } minimal: {
                Image(systemName: context.state.hasActiveRest ? "timer" : "figure.strengthtraining.traditional")
            }
        }
    }
}

@available(iOS 16.2, *)
private struct WorkoutLiveActivityView: View {
    let context: ActivityViewContext<StrengthLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: routine + session timer
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.routineName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Text(context.state.currentExerciseName)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("SESSION")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.gray)

                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
            }

            // Metrics row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROGRESS")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.gray)
                    Text(context.state.currentExerciseProgressText)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text(context.state.completedSetsText)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TARGET")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.gray)
                    Text(context.state.exerciseDetailText)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text("Exercise \(context.state.currentExerciseIndex) of \(context.state.totalExercises)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Rest footer
            HStack(spacing: 6) {
                Image(systemName: context.state.hasActiveRest ? "timer" : "checkmark.circle")
                    .foregroundColor(context.state.hasActiveRest ? .orange : .green)
                    .font(.caption)

                if let restEndAt = context.state.restEndAt, context.state.hasActiveRest,
                   restEndAt > context.state.updatedAt {
                    Text("Rest:")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                    Text(timerInterval: context.state.updatedAt...restEndAt, countsDown: true)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                } else {
                    Text("Ready for next set")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                }

                Spacer()
            }
        }
        .padding(16)
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Lock Screen - Resting", as: .content, using: StrengthLiveActivityAttributes(
    sessionId: "preview-1",
    routineName: "Upper Body",
    startedAt: .now.addingTimeInterval(-300)
)) {
    StrengthAppWorkoutLiveActivity()
} contentStates: {
    StrengthLiveActivityAttributes.ContentState(
        currentExerciseName: "Bench Press",
        currentExerciseType: "strength",
        currentExerciseIndex: 2,
        totalExercises: 5,
        completedSetsText: "4 total sets",
        currentExerciseProgressText: "1/3 sets",
        exerciseDetailText: "8 reps target",
        updatedAt: .now,
        restEndAt: .now.addingTimeInterval(45),
        restSeconds: 90,
        hasActiveRest: true
    )
}

@available(iOS 17.0, *)
#Preview("Lock Screen - Ready", as: .content, using: StrengthLiveActivityAttributes(
    sessionId: "preview-2",
    routineName: "Lower Body",
    startedAt: .now.addingTimeInterval(-600)
)) {
    StrengthAppWorkoutLiveActivity()
} contentStates: {
    StrengthLiveActivityAttributes.ContentState(
        currentExerciseName: "Barbell Squat",
        currentExerciseType: "strength",
        currentExerciseIndex: 3,
        totalExercises: 6,
        completedSetsText: "8 total sets",
        currentExerciseProgressText: "2/4 sets",
        exerciseDetailText: "5 reps target",
        updatedAt: .now,
        restEndAt: nil,
        restSeconds: 0,
        hasActiveRest: false
    )
}
