import Foundation

/// HealthKit can complete its prompt before the permission-store write is visible.
struct HealthAuthorizationSettlement {
    enum Step: Equatable {
        case recheck(after: TimeInterval)
        case settled
        case exhausted
        case finished
    }

    private var remainingRechecks = 20
    private var finished = false

    mutating func observe(isNotDetermined: Bool) -> Step {
        guard !finished else { return .finished }
        if !isNotDetermined {
            finished = true
            return .settled
        }
        guard remainingRechecks > 0 else {
            finished = true
            return .exhausted
        }
        remainingRechecks -= 1
        return .recheck(after: 0.1)
    }
}
