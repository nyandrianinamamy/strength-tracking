import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct StrengthLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentExerciseName: String
        var currentExerciseType: String
        var currentExerciseIndex: Int
        var totalExercises: Int
        var completedSetsText: String
        var currentExerciseProgressText: String
        var exerciseDetailText: String
        var updatedAt: Date
        var restEndAt: Date?
        var restSeconds: Int
        var hasActiveRest: Bool
    }

    var sessionId: String
    var routineName: String
    var startedAt: Date
}
