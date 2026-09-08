import XCTest
@testable import KotranaNativeLogic
@testable import WatchModels

final class CompanionLifecycleTests: XCTestCase {
    private func message(_ type: String, _ revision: Int64, _ session: String? = nil, sender: String = "phone-a", nonce: String? = nil) -> WatchEnvelope {
        WatchEnvelope(type: type, senderID: sender, revision: revision, sessionID: session, syncRequestID: nonce)
    }

    func testDuplicateAndDelayedEndCannotEraseNewSession() {
        var state = WatchMessageState()
        XCTAssertEqual(state.accept(message("session_update", 1, "a")), .update)
        XCTAssertEqual(state.accept(message("session_end", 2, "a")), .complete)
        XCTAssertEqual(state.accept(message("session_update", 3, "b")), .update)
        XCTAssertEqual(state.accept(message("session_end", 2, "a")), .ignore)
        XCTAssertEqual(state.accept(message("session_end", 4, "a")), .ignore)
        XCTAssertEqual(state.activeSessionID, "b")
        XCTAssertFalse(state.canClearCompletion(senderID: "phone-a", revision: 2))
    }

    func testColdIdleClearsCachedSessionAndPersistsWatermark() throws {
        var state = WatchMessageState()
        _ = state.accept(message("session_update", 8, "a"))
        state = try JSONDecoder().decode(WatchMessageState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(state.accept(message("session_idle", 9)), .idle)
        XCTAssertNil(state.activeSessionID)
        XCTAssertEqual(state.accept(message("session_update", 8, "a")), .ignore)
    }

    func testReinstalledPhoneRequiresFreshSyncNonceToAdoptCounterReset() {
        var state = WatchMessageState()
        _ = state.accept(message("session_update", 100, "a"))
        XCTAssertEqual(state.accept(message("session_idle", 1, sender: "phone-b")), .requestSync)
        XCTAssertEqual(state.accept(message("session_idle", 2, sender: "phone-b", nonce: "wrong"), expectedSyncRequestID: "fresh"), .requestSync)
        XCTAssertEqual(state.accept(message("session_idle", 3, sender: "phone-b", nonce: "fresh"), expectedSyncRequestID: "fresh"), .idle)
        XCTAssertEqual(state.accept(message("session_update", 101, "old", sender: "phone-a")), .requestSync)
        XCTAssertNil(state.activeSessionID)
        XCTAssertEqual(state.senderID, "phone-b")
    }

    func testIdentityFreeAndInvalidMessagesAreRejected() {
        XCTAssertNil(WatchEnvelope(dictionary: ["type": "session_end"]))
        var state = WatchMessageState()
        _ = state.accept(message("session_update", 1, "a"))
        XCTAssertEqual(state.accept(message("session_end", 2)), .ignore)
        XCTAssertEqual(state.activeSessionID, "a")
    }

    func testCompletedStateIsClearedOnlyByItsOwnTimer() {
        var state = WatchMessageState()
        _ = state.accept(message("session_update", 1, "a"))
        _ = state.accept(message("session_end", 2, "a"))
        XCTAssertTrue(state.canClearCompletion(senderID: "phone-a", revision: 2))
        _ = state.accept(message("session_idle", 3))
        XCTAssertFalse(state.canClearCompletion(senderID: "phone-a", revision: 2))
    }

    func testPhoneNavigationOverridesManualPageOnlyWhenPhoneMoves() {
        var page = WatchPageSelection()
        page.receive(sessionID: "a", currentIndex: 0, exerciseCount: 3)
        page.selectedIndex = 2
        page.receive(sessionID: "a", currentIndex: 0, exerciseCount: 3)
        XCTAssertEqual(page.selectedIndex, 2)
        page.receive(sessionID: "a", currentIndex: 1, exerciseCount: 3)
        XCTAssertEqual(page.selectedIndex, 1)
        page.receive(sessionID: "b", currentIndex: 0, exerciseCount: 2)
        XCTAssertEqual(page.selectedIndex, 0)
    }

    func testAuthorizationDelayRechecksSessionAndAbsoluteDeadline() {
        var lifecycle = WorkoutLifecycle()
        let start = Date(timeIntervalSince1970: 100)
        let token = lifecycle.advance(sessionID: "a")
        XCTAssertEqual(lifecycle.restInterval(token: token, endsAt: start.addingTimeInterval(30), now: start.addingTimeInterval(20)), 10)
        XCTAssertNil(lifecycle.restInterval(token: token, endsAt: start.addingTimeInterval(30), now: start.addingTimeInterval(31)))
        _ = lifecycle.advance(sessionID: nil)
        XCTAssertNil(lifecycle.restInterval(token: token, endsAt: start.addingTimeInterval(30), now: start))
        _ = lifecycle.advance(sessionID: "b")
        XCTAssertFalse(lifecycle.isCurrent(token))
    }

    func testReachableWatchIsNotRelaunchedDuringPermissionUI() {
        var policy = WatchLaunchPolicy()
        XCTAssertFalse(policy.shouldLaunch(sessionID: "a", isReachable: true))
        // A later visibility change must not introduce a delayed launch for A.
        XCTAssertFalse(policy.shouldLaunch(sessionID: "a", isReachable: false))
        XCTAssertTrue(policy.shouldLaunch(sessionID: "b", isReachable: false))
        XCTAssertFalse(policy.shouldLaunch(sessionID: "b", isReachable: false))
    }

    func testWatchLaunchIsSuppressedWhileInFlightAndResetForNextWorkout() {
        var policy = WatchLaunchPolicy()
        XCTAssertTrue(policy.shouldLaunch(sessionID: "a", isReachable: false))
        XCTAssertFalse(policy.shouldLaunch(sessionID: "a", isReachable: false))
        policy.reset()
        XCTAssertTrue(policy.shouldLaunch(sessionID: "a", isReachable: false))
    }

    func testHealthAuthorizationWaitsForDelayedDecisionAndStopsOnce() {
        // Both granted and denied are real settled decisions. Neither callback
        // success nor an untouched switch is used as a substitute for this read.
        for settledStatus in [1, 2] {
            var settlement = HealthAuthorizationSettlement()
            var pending = true
            var completionCount = 0
            for status in [0, 0, settledStatus, settledStatus] {
                switch settlement.observe(isNotDetermined: status == 0) {
                case .recheck(let delay):
                    XCTAssertTrue(pending)
                    XCTAssertEqual(delay, 0.1)
                case .settled:
                    pending = false
                    completionCount += 1
                case .finished:
                    XCTAssertFalse(pending)
                case .exhausted:
                    XCTFail("A delayed decision must settle before the bound")
                }
            }
            XCTAssertFalse(pending)
            XCTAssertEqual(completionCount, 1)
        }
    }

    func testHealthAuthorizationForeverUnknownHasFiniteRechecks() {
        var settlement = HealthAuthorizationSettlement()
        var totalDelay: TimeInterval = 0
        for _ in 0..<20 {
            guard case .recheck(let delay) = settlement.observe(isNotDetermined: true) else {
                return XCTFail("The observation should still be pending")
            }
            totalDelay += delay
        }
        XCTAssertEqual(totalDelay, 2, accuracy: 0.0001)
        XCTAssertEqual(settlement.observe(isNotDetermined: true), .exhausted)
        XCTAssertEqual(settlement.observe(isNotDetermined: true), .finished)
        // An old scheduled observation cannot finish or start anything again.
        XCTAssertEqual(settlement.observe(isNotDetermined: false), .finished)
    }

    func testFrenchLabelsAndLocaleNormalization() {
        XCTAssertEqual(WorkoutStrings.string("target", locale: "fr-FR"), "Objectif")
        XCTAssertEqual(WorkoutStrings.string("last", locale: "en-US"), "Last")
        XCTAssertEqual(WorkoutStrings.setOf(1, 3, locale: "fr"), "SÉRIE 1/3")
        XCTAssertEqual(WorkoutStrings.string("rest_complete", locale: "fr"), "Repos terminé")
    }

    func testLegacyCacheRemainsDecodableAfterRemovingUnusedIncrement() throws {
        let raw = #"{"sessionId":"a","routineId":"r","routineName":"Routine","startedAt":"2026-09-08T08:00:00Z","currentExerciseIndex":0,"locale":"fr","unit":"lbs","weightIncrement":5,"exercises":[{"exerciseId":"press","name":"Press","exerciseType":"strength","targetSets":3,"targetReps":8,"restSeconds":60,"recommendedWeightKg":20,"completedSets":[]}]}"#
        let snapshot = try JSONDecoder().decode(SessionSnapshot.self, from: Data(raw.utf8))
        XCTAssertEqual(snapshot.locale, "fr")
        XCTAssertEqual(snapshot.exercises.first?.suggestedWeightKg, 20)
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
        XCTAssertNil(saved["weightIncrement"])
    }
}
