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
                    RestFooterView(context: context)
                }
            } compactLeading: {
                Text("\(context.state.currentExerciseIndex)/\(context.state.totalExercises)")
                    .font(.caption2.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } compactTrailing: {
                if let restEndAt = context.state.restEndAt, context.state.hasActiveRest,
                   restEndAt >= context.state.updatedAt {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.routineName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(context.state.currentExerciseName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("SESSION")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .fixedSize()
                }
            }

            HStack(spacing: 12) {
                MetricCard(
                    title: "Progress",
                    value: context.state.currentExerciseProgressText,
                    detail: context.state.completedSetsText
                )

                MetricCard(
                    title: "Target",
                    value: context.state.exerciseDetailText,
                    detail: "Exercise \(context.state.currentExerciseIndex) of \(context.state.totalExercises)"
                )
            }

            RestFooterView(context: context)
        }
        .padding(16)
    }
}

@available(iOS 16.2, *)
private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

@available(iOS 16.2, *)
private struct RestFooterView: View {
    let context: ActivityViewContext<StrengthLiveActivityAttributes>

    var body: some View {
        HStack {
            Image(systemName: context.state.hasActiveRest ? "timer" : "figure.cooldown")
                .foregroundStyle(context.state.hasActiveRest ? Color.orange : Color.green)

            if let restEndAt = context.state.restEndAt, context.state.hasActiveRest,
               restEndAt >= context.state.updatedAt {
                Text("Rest")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(timerInterval: context.state.updatedAt...restEndAt, countsDown: true)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            } else {
                Text("Ready for the next set")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
