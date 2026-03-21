import Foundation

struct WatchExercise: Codable, Identifiable {
    let exerciseId: String
    let name: String
    let exerciseType: String // "strength" or "timed"
    let targetSets: Int
    let targetReps: Int
    let targetDurationSeconds: Int?
    let restSeconds: Int
    let suggestedWeightKg: Double
    let completedSets: [WatchCompletedSet]

    var id: String { exerciseId }

    var isStrength: Bool { exerciseType == "strength" }
    var isTimed: Bool { exerciseType == "timed" }

    enum CodingKeys: String, CodingKey {
        case exerciseId
        case name
        case exerciseType
        case targetSets
        case targetReps
        case targetDurationSeconds
        case restSeconds
        case suggestedWeightKg
        case recommendedWeightKg
        case completedSets
    }

    init(
        exerciseId: String,
        name: String,
        exerciseType: String,
        targetSets: Int,
        targetReps: Int,
        targetDurationSeconds: Int?,
        restSeconds: Int,
        suggestedWeightKg: Double,
        completedSets: [WatchCompletedSet]
    ) {
        self.exerciseId = exerciseId
        self.name = name
        self.exerciseType = exerciseType
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetDurationSeconds = targetDurationSeconds
        self.restSeconds = restSeconds
        self.suggestedWeightKg = suggestedWeightKg
        self.completedSets = completedSets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        name = try container.decode(String.self, forKey: .name)
        exerciseType = try container.decode(String.self, forKey: .exerciseType)
        targetSets = try container.decode(Int.self, forKey: .targetSets)
        targetReps = try container.decode(Int.self, forKey: .targetReps)
        targetDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .targetDurationSeconds)
        restSeconds = try container.decode(Int.self, forKey: .restSeconds)
        suggestedWeightKg = try container.decodeIfPresent(Double.self, forKey: .suggestedWeightKg)
            ?? container.decodeIfPresent(Double.self, forKey: .recommendedWeightKg)
            ?? 0
        completedSets = try container.decode([WatchCompletedSet].self, forKey: .completedSets)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(exerciseId, forKey: .exerciseId)
        try container.encode(name, forKey: .name)
        try container.encode(exerciseType, forKey: .exerciseType)
        try container.encode(targetSets, forKey: .targetSets)
        try container.encode(targetReps, forKey: .targetReps)
        try container.encodeIfPresent(targetDurationSeconds, forKey: .targetDurationSeconds)
        try container.encode(restSeconds, forKey: .restSeconds)
        try container.encode(suggestedWeightKg, forKey: .suggestedWeightKg)
        try container.encode(completedSets, forKey: .completedSets)
    }
}
