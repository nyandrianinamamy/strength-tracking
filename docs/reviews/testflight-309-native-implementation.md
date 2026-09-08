# Native implementation status

Implemented against `v1.0.31+309` on `codex/testflight-309-ios-watch-review`. This records source and focused checks. Final simulator and archive results are in the [implementation record](2026-09-08-implementation-record.md).

| Finding | Change |
| --- | --- |
| N1 | The phone stamps protocol v2 messages with a persisted sender UUID and revision. Watch persists its accepted sender/revision separately from its display cache, rejects stale/duplicate/unidentified messages, and scopes completion to the matching session. A new phone installation adopts its reset counter through a fresh Watch sync nonce. Completion clears persisted display data immediately and cancels/scopes the delayed UI dismissal. Latest application context includes end/idle, replacing duplicate `transferUserInfo` completion queues. |
| N2 | Dart sends authoritative idle on cold startup and explicit sync requests. Repeated unchanged idle state is coalesced so it does not immediately erase the completion display. Native replies can use its current snapshot while Flutter is attaching/rebuilding. |
| N3 | Watch follows changes to the phone's session/exercise index. Manual Watch paging remains until the phone moves to another exercise. |
| N4 | Live Activity operations run in order and check a lifecycle token. Rest notification tasks are cancelled on state changes; they recheck the token and absolute deadline after authorization. Each scheduled alert has a unique identifier, so an obsolete add completion cannot remove a newer alert. |
| N5 | Watch labels, idle/completion state, widget labels and notifications share English/French strings. Locale is persisted on Watch and included in Live Activity content. Dart payloads use generated localization getters and the shared exercise-name resolver. |
| M4 | Watch requests Health authorization once per process, permits snapshot updates while authorization is pending, and only starts the current session after the real response. A delayed failure from an old HealthKit workout cannot clear the new workout reference. The phone no longer requests workout read/write permission merely to launch the Watch app. Acceptance reads the actual permission status and preserves observed-state diagnostics; no fake grants or permission database edits are used. |

Cleanup removes obsolete Watch log-event forwarding, unused weight increments, unused view rest-state parameters, unused localization keys, and the duplicate exercise-name resolver. The Live Activity attribute type now has one source shared by the app and extension. Old cached weight recommendations and extra removed fields still decode.

The app target now declares the existing Podfile floor of iOS 15; dependency targets below that floor inherit 15 without lowering higher requirements. Live Activity stays at iOS 16.2 and Watch at watchOS 10. Native managers type-check at iOS 15; Watch sources type-check at watchOS 10 with the project's actor/concurrency settings. This does not substitute for the release Xcode 26.3 build; local checks use Xcode 27 beta.

## Focused verification

- `tool/ci/run_native_regressions.sh`: 13 passing Foundation/Swift tests, including delayed/duplicate completion, nonce-based reinstall, persisted idle watermark, completion timer scope, paging policy, rest deadline/token invalidation, French labels, old cache decoding, and Watch launch suppression/reset.
- Flutter 3.41.9: 20 passing Watch/Live Activity tests, including cold idle/nonce, provider disposal, deferred same-session snapshots, completion suppression, and French payloads. Host fixtures explicitly disable HealthKit; paired acceptance uses the real native authorization flow.
- Native Swift type-checks pass for both deployment floors; Xcode project plist and Podfile syntax checks pass.
- The native integration suite now asserts actual Live Activity identity/content/locale and removal, using a Debug-only observation method.
- The real paired simulator transport run passed initial receipt, next exercise, immediate end-A/start-B with B preserved for five seconds, and final idle. Evidence: `build/implementation-evidence/watch-observation2/`. Real Watch AX captures separately confirmed the timed exercise and French idle screen. Health returned sharing-denied with no request pending; this proves optional-Health behavior, not an authorized HealthKit session.

The paired driver now requires the AX helper at every workout/idle checkpoint. It requires two fresh captures of the visible expected screen, no unresolved permission dialog, and settled actual Health authorization (denied or granted). Missing AXe or an unknown permission screen fails the run. The integrated run with these mandatory UI assertions remains assigned to the root task.

Fresh simulator preparation accounts for two verified toolchain behaviors: Flutter reinstalls the phone app and removes its companion, so the host installs Watch after the phone test starts; watchOS can activate before its connectivity daemon has indexed a fresh companion, so a bounded process relaunch retries registration while still requiring real reachability. Flutter normally uninstalls the phone when drive finishes; retain it explicitly when investigating Watch state after a run.

Focused evidence is under `build/implementation-evidence/native/`. The paired driver stores the last observed session/index, actual permission state, receipt JSON, AX trees and screenshots on failure. Watch starts and ends an `HKWorkoutSession` to maintain foreground availability; there is no workout builder, finish/save flow, or HealthKit export. Physical Watch background delivery, wrist/haptic behavior, auto-launch, authorized HealthKit session/background behavior, and signed upgrade remain device acceptance checks.

## Release configuration follow-up

The final configuration audit found and repaired two metadata defects:

- Runner and Watch directly use `UserDefaults` but had no app-owned privacy manifest. Each now declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` for its private preferences. Runner includes the file explicitly in Resources; Watch includes it through its synchronized target folder. Apple requires a manifest in each executable's bundle and a declaration for direct app API use; SDK manifests do not cover this native code. [Apple required-reason API rules](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [UserDefaults reason codes](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
- The Health permission descriptions promised saving workout summaries or syncing them to other apps. They now describe phone read access for sleep, heart rate variability and resting heart rate, and Watch workout access for keeping the session visible. The HealthKit entitlements and actual authorization request remain intact. All three Watch build-configuration description overrides match its Info.plist.

`release-metadata-check.json` records manifest schema, target membership and description consistency checks; plist syntax and the Xcode project pass validation. Verification that the new files appear in rebuilt bundles remains part of the root build. Existing simulator bundle evidence already confirms Runner contains both `Watch/StrengthAppWatch Watch App.app` and `PlugIns/StrengthAppLiveActivity.appex`, with deployment floors 15.0, 10.0 and 16.2 respectively. Shared Swift source membership, target dependencies, Watch companion identifier, HealthKit/Apple sign-in entitlements, and all three Fastlane export profile mappings are consistent.

The release workflow resolves the requested tag once to a commit SHA; both the reusable quality job and TestFlight build check out that SHA. Upload depends on successful quality completion, and the runner preserves any suite failure in its final exit status. No further concrete release-configuration defect was found in this pass.


### Collection declaration

Runner's manifest declares account-linked name, email, user ID, body weight, fitness history, optional machine photos, custom text and profile/preferences for app functionality and applicable training personalization, with tracking disabled. Raw HealthKit histories stay in the local training-engine cache and are absent from the Firestore AppState payload. Watch retains its private-UserDefaults declaration because it performs no developer-accessible backend collection. App Store Connect privacy labels remain separate release metadata. See [Apple TN3184](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest) and [the collection categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype). Source mapping and validated category identifiers are recorded in `build/implementation-evidence/native/privacy-collection-amendment.md`.

### Permission prompt interruption found by the aggregate

The strict paired test exposed a phone auto-launch dismissing the Watch Health prompt. Native Carousel logs show the Health sheet visible, followed by the phone's `watchkit:///workout` workspace request and an explicit dismiss-alerts action. The callback then returned with no reported error and cached not-determined status. The current evidence cannot distinguish a later Health database update from that cached callback value; the driver assertion remains unchanged.

The phone now skips HealthKit auto-launch for an already reachable Watch. It still records a session before attempting launch, suppresses duplicate/in-flight requests and resets on end/idle. Two Foundation regressions cover that policy. The Watch logs callback success, error domain/code and one sampled numeric authorization status, without identity or error payloads. Eleven native regressions pass; the real paired rerun remains the acceptance check. Full chronology and logs are under `build/implementation-evidence/native/watch-health-final-diagnosis.md`.


## Delayed Health authorization visibility

The fresh run on Watch `140776E9-72DB-455E-9044-B7F1FE3E0ADC` reached the workout UI after Review, scroll, and Done with the Workouts switch untouched. At 09:55:34.715 the actual callback logged `success=true`, no error, and status `0` (not determined). Healthd began its authorization-change sync 22 ms later. Replaying on the same installed pair after restarting the Watch process read status `1` (denied) and passed the strict paired checkpoints. The replay's helper events contained only expected workout screens; it did **not** exercise the new explicit-grant helper. Evidence: `build/implementation-evidence/native/watch-done-authorization*.log` and `build/implementation-evidence/paired-permission-final/checkpoints/`.

The callback previously sampled status once, so it could leave the diagnostic preference stale and miss starting an authorized HealthKit session until a later snapshot or restart. It now keeps authorization pending and reads the real `HKHealthStore` status again every 100 ms while it remains undetermined, for at most 20 rechecks. A determined result stops rechecks and clears pending; an authorized result passes through the existing current-session and already-started guards. Exhaustion clears pending while retaining the actual unknown status, so strict acceptance still fails rather than treating it as a decision. Snapshot transport and display continue while authorization is pending.

Two additional native policy tests cover delayed denial/authorization, exactly one terminal decision, and the forever-unknown two-second retry bound. All 13 native tests pass; the full Watch sources type-check at watchOS 10 with the project's Swift 5 and MainActor settings. Logs: `native/swift-after-health-recheck.log` and `native/watch-after-health-recheck-typecheck.log` under the implementation evidence directory. A rebuilt fresh-pair permission/UI run remains assigned to the root task.
