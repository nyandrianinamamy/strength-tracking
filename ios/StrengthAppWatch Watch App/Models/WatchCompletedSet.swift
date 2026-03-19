import Foundation

struct WatchCompletedSet: Codable, Identifiable {
    let setNumber: Int
    let weightKg: Double
    let reps: Int
    let durationSeconds: Int?
    let completedAt: String

    var id: Int { setNumber }
}
