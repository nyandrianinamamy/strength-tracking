import Foundation

struct SessionSnapshot: Codable {
    let sessionId: String
    let routineId: String
    let routineName: String
    let startedAt: String
    let currentExerciseIndex: Int
    let exercises: [WatchExercise]
    let activeRest: WatchRestState?
    var locale: String
    var unit: String

    enum CodingKeys: String, CodingKey {
        case sessionId, routineId, routineName, startedAt, currentExerciseIndex, exercises, activeRest
        case locale, unit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        routineId = try container.decode(String.self, forKey: .routineId)
        routineName = try container.decode(String.self, forKey: .routineName)
        startedAt = try container.decode(String.self, forKey: .startedAt)
        currentExerciseIndex = try container.decode(Int.self, forKey: .currentExerciseIndex)
        exercises = try container.decode([WatchExercise].self, forKey: .exercises)
        activeRest = try container.decodeIfPresent(WatchRestState.self, forKey: .activeRest)
        locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? "en"
        unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "kg"
    }

    init(sessionId: String, routineId: String, routineName: String, startedAt: String, currentExerciseIndex: Int, exercises: [WatchExercise], activeRest: WatchRestState? = nil, locale: String, unit: String) {
        self.sessionId = sessionId
        self.routineId = routineId
        self.routineName = routineName
        self.startedAt = startedAt
        self.currentExerciseIndex = currentExerciseIndex
        self.exercises = exercises
        self.activeRest = activeRest
        self.locale = locale
        self.unit = unit
    }
}

struct WatchRestState: Codable {
    let sourceExerciseId: String
    let sourceExerciseName: String
    let startedAt: String
    let endsAt: String
    let restSeconds: Int
}
