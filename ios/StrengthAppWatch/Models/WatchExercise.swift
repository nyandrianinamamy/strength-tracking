import Foundation

struct WatchExercise: Codable, Identifiable {
    let exerciseId: String
    let name: String
    let exerciseType: String // "strength" or "timed"
    let targetSets: Int
    let targetReps: Int
    let targetDurationSeconds: Int?
    let restSeconds: Int
    let recommendedWeightKg: Double
    let completedSets: [WatchCompletedSet]

    var id: String { exerciseId }

    var isStrength: Bool { exerciseType == "strength" }
    var isTimed: Bool { exerciseType == "timed" }
}
