import Foundation

struct SessionSnapshot: Codable {
    let sessionId: String
    let routineId: String
    let routineName: String
    let startedAt: String
    let currentExerciseIndex: Int
    let exercises: [WatchExercise]
    var locale: String
    var unit: String
    var weightIncrement: Double

    enum CodingKeys: String, CodingKey {
        case sessionId, routineId, routineName, startedAt, currentExerciseIndex, exercises
        case locale, unit, weightIncrement
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        routineId = try container.decode(String.self, forKey: .routineId)
        routineName = try container.decode(String.self, forKey: .routineName)
        startedAt = try container.decode(String.self, forKey: .startedAt)
        currentExerciseIndex = try container.decode(Int.self, forKey: .currentExerciseIndex)
        exercises = try container.decode([WatchExercise].self, forKey: .exercises)
        locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? "en"
        unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "kg"
        weightIncrement = try container.decodeIfPresent(Double.self, forKey: .weightIncrement) ?? 2.5
    }

    init(sessionId: String, routineId: String, routineName: String, startedAt: String, currentExerciseIndex: Int, exercises: [WatchExercise], locale: String, unit: String, weightIncrement: Double) {
        self.sessionId = sessionId
        self.routineId = routineId
        self.routineName = routineName
        self.startedAt = startedAt
        self.currentExerciseIndex = currentExerciseIndex
        self.exercises = exercises
        self.locale = locale
        self.unit = unit
        self.weightIncrement = weightIncrement
    }
}
