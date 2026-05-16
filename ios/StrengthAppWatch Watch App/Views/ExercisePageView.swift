import SwiftUI

struct ExercisePageView: View {
    let snapshot: SessionSnapshot
    let activeRestRemaining: Int

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
                            activeRest: snapshot.activeRest,
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
                            activeRest: snapshot.activeRest,
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
