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
            Text("Kotrana")
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
            activeRestRemaining: sessionManager.activeRestRemaining
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
