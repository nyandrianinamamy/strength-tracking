import SwiftUI

struct ExercisePageView: View {
    let snapshot: SessionSnapshot
    let onLogSet: (String, Int, Double, Int) -> Void        // exerciseId, setNumber, weightKg, reps
    let onLogTimedSet: (String, Int, Int) -> Void            // exerciseId, setNumber, durationSeconds

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
                            locale: snapshot.locale,
                            onLogTimedSet: { durationSeconds in
                                let setNumber = exercise.completedSets.count + 1
                                onLogTimedSet(exercise.exerciseId, setNumber, durationSeconds)
                            }
                        )
                    } else {
                        StrengthExerciseView(
                            exercise: exercise,
                            exerciseIndex: index,
                            totalExercises: snapshot.exercises.count,
                            nextExerciseName: nextName(after: index),
                            sessionStartedAt: snapshot.startedAt,
                            locale: snapshot.locale,
                            unit: snapshot.unit,
                            weightIncrement: snapshot.weightIncrement,
                            onLogSet: { weightKg, reps in
                                let setNumber = exercise.completedSets.count + 1
                                onLogSet(exercise.exerciseId, setNumber, weightKg, reps)
                            }
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
