import Foundation

struct LogSetMessage: Codable {
    let type: String // "log_set" or "log_timed_set"
    let exerciseId: String
    let setNumber: Int
    let weightKg: Double?       // nil for timed sets
    let reps: Int?              // nil for timed sets
    let durationSeconds: Int?   // nil for strength sets
    let completedAt: String

    static func strength(exerciseId: String, setNumber: Int, weightKg: Double, reps: Int) -> LogSetMessage {
        return LogSetMessage(
            type: "log_set",
            exerciseId: exerciseId,
            setNumber: setNumber,
            weightKg: weightKg,
            reps: reps,
            durationSeconds: nil,
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    static func timed(exerciseId: String, setNumber: Int, durationSeconds: Int) -> LogSetMessage {
        return LogSetMessage(
            type: "log_timed_set",
            exerciseId: exerciseId,
            setNumber: setNumber,
            weightKg: nil,
            reps: nil,
            durationSeconds: durationSeconds,
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "exerciseId": exerciseId,
            "setNumber": setNumber,
            "completedAt": completedAt,
        ]
        if let w = weightKg { dict["weightKg"] = w }
        if let r = reps { dict["reps"] = r }
        if let d = durationSeconds { dict["durationSeconds"] = d }
        return dict
    }
}
