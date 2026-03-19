import Foundation

struct SessionSnapshot: Codable {
    let routineId: String
    let routineName: String
    let startedAt: String
    let currentExerciseIndex: Int
    let exercises: [WatchExercise]
    let locale: String
    let unit: String
    let weightIncrement: Double
}
