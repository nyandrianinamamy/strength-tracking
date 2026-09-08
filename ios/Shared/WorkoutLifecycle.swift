import Foundation

struct WorkoutLifecycle {
    struct Token: Equatable {
        fileprivate let revision: Int
        fileprivate let sessionID: String?
    }
    private var current = Token(revision: 0, sessionID: nil)

    mutating func advance(sessionID: String?) -> Token {
        current = Token(revision: current.revision + 1, sessionID: sessionID)
        return current
    }

    func isCurrent(_ token: Token) -> Bool { token == current }

    func restInterval(token: Token, endsAt: Date, now: Date) -> TimeInterval? {
        guard isCurrent(token), token.sessionID != nil else { return nil }
        let interval = endsAt.timeIntervalSince(now)
        return interval > 1 ? interval : nil
    }
}

/// Opening an already visible Watch app can dismiss its Health permission sheet.
struct WatchLaunchPolicy {
    private var lastSessionID: String?

    mutating func shouldLaunch(sessionID: String, isReachable: Bool) -> Bool {
        guard sessionID != lastSessionID else { return false }
        // Mark before launching so duplicate updates cannot race an in-flight launch.
        lastSessionID = sessionID
        return !isReachable
    }

    mutating func reset() { lastSessionID = nil }
}
