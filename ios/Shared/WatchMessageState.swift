import Foundation

struct WatchEnvelope {
    let type: String
    let senderID: String
    let revision: Int64
    let sessionID: String?
    let syncRequestID: String?

    init(type: String, senderID: String, revision: Int64, sessionID: String?, syncRequestID: String? = nil) {
        self.type = type
        self.senderID = senderID
        self.revision = revision
        self.sessionID = sessionID
        self.syncRequestID = syncRequestID
    }

    init?(dictionary: [String: Any]) {
        guard dictionary["protocolVersion"] as? Int == 2,
              let type = dictionary["type"] as? String,
              ["session_update", "session_end", "session_idle"].contains(type),
              let sender = dictionary["senderId"] as? String, !sender.isEmpty,
              let revision = dictionary["revision"] as? NSNumber, revision.int64Value > 0 else { return nil }
        self.init(type: type, senderID: sender, revision: revision.int64Value,
                  sessionID: dictionary["sessionId"] as? String,
                  syncRequestID: dictionary["syncRequestId"] as? String)
    }
}

/// Persisted separately from the display cache so a late update cannot revive
/// a completed workout after the Watch process restarts.
struct WatchMessageState: Codable {
    enum Action: Equatable { case update, complete, idle, ignore, requestSync }
    private(set) var senderID: String?
    private(set) var revision: Int64 = 0
    private(set) var activeSessionID: String?

    mutating func accept(_ message: WatchEnvelope, expectedSyncRequestID: String? = nil) -> Action {
        if let senderID, senderID != message.senderID {
            guard let expectedSyncRequestID,
                  expectedSyncRequestID == message.syncRequestID else { return .requestSync }
        } else if senderID == message.senderID && message.revision <= revision {
            return .ignore
        }
        if message.type == "session_update" {
            guard let id = message.sessionID, !id.isEmpty else { return .ignore }
            senderID = message.senderID
            revision = message.revision
            activeSessionID = id
            return .update
        }
        if message.type == "session_end" {
            guard let id = message.sessionID, id == activeSessionID else { return .ignore }
        }
        senderID = message.senderID
        revision = message.revision
        activeSessionID = nil
        return message.type == "session_end" ? .complete : .idle
    }

    func canClearCompletion(senderID: String, revision: Int64) -> Bool {
        self.senderID == senderID && self.revision == revision && activeSessionID == nil
    }
}

struct WatchPageSelection {
    var selectedIndex = 0
    private var sessionID: String?
    private var phoneIndex: Int?

    mutating func receive(sessionID: String, currentIndex: Int, exerciseCount: Int) {
        let upper = max(0, exerciseCount - 1)
        if self.sessionID != sessionID || phoneIndex != currentIndex {
            selectedIndex = min(max(0, currentIndex), upper)
        } else {
            selectedIndex = min(max(0, selectedIndex), upper)
        }
        self.sessionID = sessionID
        phoneIndex = currentIndex
    }
}
