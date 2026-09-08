import SwiftUI

struct ExercisePageView: View {
    let snapshot: SessionSnapshot
    let activeRestRemaining: Int

    @State private var selection = WatchPageSelection()

    var body: some View {
        TabView(selection: $selection.selectedIndex) {
            ForEach(Array(snapshot.exercises.enumerated()), id: \.element.id) { index, exercise in
                Group {
                    if exercise.isTimed {
                        TimedExerciseView(
                            exercise: exercise,
                            exerciseIndex: index,
                            totalExercises: snapshot.exercises.count,
                            nextExerciseName: nextName(after: index),
                            sessionStartedAt: snapshot.startedAt,
                            activeRestRemaining: activeRestRemaining,
                            locale: snapshot.locale
                        )
                    } else {
                        StrengthExerciseView(
                            exercise: exercise,
                            exerciseIndex: index,
                            totalExercises: snapshot.exercises.count,
                            nextExerciseName: nextName(after: index),
                            sessionStartedAt: snapshot.startedAt,
                            activeRestRemaining: activeRestRemaining,
                            locale: snapshot.locale,
                            unit: snapshot.unit
                        )
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .onAppear { receivePhoneSelection() }
        .onChange(of: snapshot.sessionId) { _, _ in receivePhoneSelection() }
        .onChange(of: snapshot.currentExerciseIndex) { _, _ in receivePhoneSelection() }
        .onChange(of: snapshot.exercises.count) { _, _ in receivePhoneSelection() }
    }

    // Manual paging is kept until the phone changes its current exercise.
    private func receivePhoneSelection() {
        selection.receive(sessionID: snapshot.sessionId,
                          currentIndex: snapshot.currentExerciseIndex,
                          exerciseCount: snapshot.exercises.count)
    }

    private func nextName(after index: Int) -> String? {
        let next = index + 1
        guard next < snapshot.exercises.count else { return nil }
        return snapshot.exercises[next].name
    }
}
