# TestFlight 309 native review

Reviewed 2026-09-08 at tag `v1.0.31+309`, commit `e288c4984dc4ea9fe36468cd37fed64bdde42f47`, on branch `codex/testflight-309-ios-watch-review`.

Scope: all application Swift files in `ios/Runner`, `ios/StrengthAppLiveActivity`, and `ios/StrengthAppWatch Watch App`; `ios/WatchSessionManager.swift`; Dart Watch/Live Activity services and their tests; Xcode target/scheme wiring; CocoaPods and TestFlight configuration. Findings are source-based. Native sources on local `main` match this tag. No application code was changed for this review.

## Findings

Paths and line numbers refer to the tagged snapshot.

| ID | Priority | Evidence and failure | Planned fix and regression check |
| --- | --- | --- | --- |
| N1 | P1 | `ios/WatchSessionManager.swift:65-67` sends `session_end` without an ID; lines 151-164 queue it twice when unreachable. `ios/StrengthAppWatch Watch App/WorkoutSessionManager.swift:124-135` ends the current workout and schedules an unconditional snapshot/cache clear after three seconds. An old end arriving after a new workout, or starting a new workout during that interval, clears the new workout. | Include session ID and revision in messages, reject stale messages, deduplicate completion, and cancel or scope the delayed clear. Test duplicate/delayed end and A-end/B-start within three seconds. |
| N2 | P2 | `lib/src/features/watch/watch_sync_service.dart:85-93` sends nothing for an idle phone when `_lastSentSessionId` is null, including after process restart. Watch restores its cached workout at `WorkoutSessionManager.swift:294-298`; an explicit sync request reaches the same no-op phone path. | Send authoritative idle state on initialization and explicit sync. Reconcile cache on reconnect. Test cached Watch session plus restarted idle phone. |
| N3 | P2 | `ios/StrengthAppWatch Watch App/Views/ExercisePageView.swift:42-44` assigns the selected page only in `onAppear`. Later phone exercise-index changes update the snapshot but leave the visible Watch page unchanged. | Observe session/index changes with an explicit policy for manual Watch paging. Verify changing exercise on the phone while Watch remains visible. |
| N4 | P2 | `ios/Runner/StrengthLiveActivityManager.swift:143-173` calculates the notification interval before awaiting authorization and schedules afterward without checking the session. Completion can cancel the pending notification before this operation adds it; delayed permission also shifts the alert past its intended deadline. | Serialize/revise lifecycle operations, reject obsolete work after suspension, and calculate remaining time immediately before scheduling. Test delayed authorization followed by completion and expired rest deadline. |
| N5 | P2 | Watch hardcodes English labels in `Views/StrengthExerciseView.swift:44-47,75`, `Views/TimedExerciseView.swift:52-53,83,89`, and idle `ContentView.swift:54-59`. Live Activity text is hardcoded in `lib/src/features/live_activity/workout_live_activity_service.dart:155-158,205-208`, the widget, and native notifications. | Carry/persist locale and localize the companion surfaces. Verify English/French idle, strength, timed exercise, rest, completion, and notifications. |

The tagged Dart service already includes the earlier guard against an in-flight active snapshot sent after session completion (`watch_sync_service.dart:315-336`). Preserve that guard and its regression test while fixing native ordering.

## Keep/remove inventory

| Component | Decision | Dependency or condition |
| --- | --- | --- |
| `ios/Runner`, `ios/Runner.xcodeproj`, `ios/Runner.xcworkspace`, Flutter/CocoaPods configuration | Keep | iPhone application, plugin registration, Watch bridge, build and signing targets. Keep `Podfile.lock` and the shared schemes. |
| `ios/StrengthAppWatch Watch App` and its target, entitlements, assets | Keep | The companion is embedded by Runner's `Embed Watch Content` phase. Current product behavior is display-only. |
| `ios/StrengthAppLiveActivity` and its target | Keep | Lock Screen/Dynamic Island functionality is part of the iOS app. Preserve Runner's embedded-extension dependency and signing profile. |
| Flutter `lib`, localization/assets, local Dart packages | Keep required dependencies | The iOS application is implemented in Flutter. Removing other platform hosts does not make these disposable. |
| Firebase/Auth configuration and private invitation enforcement | Keep | Required by invited iOS users; native platform cleanup must not alter access semantics. |
| `ios/fastlane`, `.github/workflows/build-ios.yml` | Keep and fix validation gates | Preserve three signed bundle identifiers. Do not publish during cleanup verification. |
| `ios/build/**` | Remove from Git | 61 tracked PIF-cache JSON files, 3,403,104 bytes. Already ignored by `.gitignore`, but still tracked. Rebuild regenerates them. |
| Native `log_set`/`log_timed_set` forwarding, `ios/WatchSessionManager.swift:266-267` | Remove | Dart intentionally ignores these events; `watch_sync_service_test.dart:458` verifies display-only behavior. Keep `request_sync`. |
| `weightIncrement` in Dart/native Watch payload and `SessionSnapshot` | Remove coordinated plumbing | It is transported/cached but has no current consumer. Keep tolerant decoding of old caches/payloads during migration. |
| `activeRest` parameters in `StrengthExerciseView` and `TimedExerciseView` | Remove | Neither view reads the parameter. Keep `activeRestRemaining` and the manager's rest state/haptic logic. |
| Duplicate `StrengthLiveActivityAttributes.swift` files | Consolidate | Use one shared source included in both Runner and extension targets; both require the same Codable contract. |
| Unreferenced `WatchLocalizations.swift` keys and `WatchExercise.isStrength` | Remove after reference check | Prune obsolete controls while adding the missing labels from N5. |
| `recommendedWeightKg` decoding fallback in `WatchExercise` | Keep pending compatibility decision | It accepts earlier payload/cache schema. Absence of current writers does not prove old stored data is gone. |

Other platform host removals belong in the repository-wide cleanup plan. Native package transitive dependencies should remain in lockfiles until the package resolver removes them; platform names alone do not establish dead code.

Deployment declarations need reconciliation: Podfile sets iOS 15, project configurations still contain iOS 13, Live Activity requires iOS 16.2, and Watch requires watchOS 10. Choose the supported product minimum against installed dependency requirements, then align build settings. Do not raise the minimum solely to simplify cleanup.

## Existing verification and its limits

- `ios/RunnerTests/RunnerTests.swift:7` contains only an empty `testExample`. No Watch test target exists.
- Dart Watch tests mock platform channels. They cover payloads, first-send retry, active-session lifecycle, engine recommendations, and the completion guard; they do not exercise WatchConnectivity delivery or Swift presentation.
- `integration_test/native_runtime_wiring_test.dart:22-47` checks native channel acceptance and that pairing/reachability return booleans. It does not require a paired Watch or inspect Watch receipt.
- Its Live Activity check at lines 50-78 verifies method completion, not Activity creation or rendering. `StrengthLiveActivityManager.swift:124` swallows Activity-request errors, so this check can pass with no displayed activity.
- `.github/workflows/build-ios.yml` has no analyze/unit/integration gate before upload. `ios/fastlane/Fastfile:141` skips the wait for processing; upload success alone does not establish processing or tester assignment.

## Native test implementation plan

Added `integration_test/paired_watch_test.dart` and `test_driver/paired_watch_driver.dart` during this review. They exercise the real iOS method channel, WatchConnectivity delivery, native decoding, and Watch UserDefaults cache without modifying production code or injecting Watch receipts. Both selected devices must be booted simulators in the same pair. The phone calls the real `device_info_plus` native channel and requires `isPhysicalDevice == false`; the runner also declares its simulator UDID, which the host checks against the selected pair. The test requires native pairing and reachability, checks session A, its next exercise/completed set, end-A/start-B, B remaining present for five seconds, and final cache clearing. The host polls cache receipts with deadlines, saves minimal matching receipt JSON and screenshots, and fails on setup, missing receipt, or state loss. Screenshot capture does not assert visual correctness. Source analysis passes; the root task records the actual runtime outcome separately. The first runtime attempt exposed that Dart's iOS environment does not export `SIMULATOR_UDID`; the native guard replaces that invalid test assumption.

The driver uses a test-only `IntegrationTestWidgetsFlutterBinding.callback` handshake. The local SDK's iOS screenshot API rejects callback arguments and processes host screenshots after test completion, so it cannot synchronize these receipt assertions.

Run through the common isolated runner:

```bash
IOS_E2E_SIMULATOR_UDID=<booted-test-iphone-udid> \
WATCH_SIMULATOR_UDID=<paired-booted-test-watch-udid> \
PAIRED_WATCH_OUTPUT_DIR="$PWD/build/paired-watch-e2e" \
tool/ci/run_ios_e2e.sh --paired-watch
```

The simulator pair must already exist. After Flutter has installed/launched the phone test, the host driver validates the built companion's bundle ID and installs/launches it on the selected Watch simulator, then reads its cache. Installation must occur here because reinstalling the phone app can remove its companion. `PAIRED_WATCH_APP_PATH` can override the default built `Runner.app/Watch/StrengthAppWatch Watch App.app` location. Remaining work after these transport checks:

1. Add deterministic Swift state/transport tests. Extract only the session reducer, revision checks, completion scheduling, and notification scheduling behind injected clock/transport interfaces. Run these in a macOS XCTest target or Swift package in CI, sharing the production source. Feed the same serialized Dart fixtures into native decoders. Cover N1/N2/N4, invalid payloads, old cache decoding, and out-of-order updates without requiring a physical Watch.
2. Keep real iOS channel integration checks and add observable assertions: native Activity ID/current content/end state and pending notification state. Put test-only access behind Debug/test configuration. Make unsupported/unavailable behavior explicit; do not equate a swallowed native error with success.
3. Build both iOS and watchOS simulator destinations with pinned Xcode/Flutter. Add fixture-driven Watch rendering checks for idle, strength/timed exercises, French, pounds, rest, and completion. Add a Watch XCTest target for watchOS-specific manager/view-state behavior if needed. Keep these separate from transport E2E: injecting a snapshot verifies its handling, not its delivery from the phone.
4. Add a paired-device E2E runner on a dedicated Mac with a test iPhone/Watch and isolated app data. Use the app's real UI to start/update/end a workout; collect bounded, session-scoped receipt/state acknowledgments from the Watch and assert them. First validate which paired-simulator transport operations work with the pinned runtime; use them in CI only after repeated passing runs. Do not make general GitHub-hosted CI depend on reliable WatchConnectivity or assume Watch UI automation is available.
5. Gate pull requests on Dart tests, iOS integration, deterministic native tests, and both simulator builds. Gate TestFlight on those checks plus recorded paired-device acceptance. Preserve `.xcresult`, integration logs, fixture screenshots, revision/toolchain metadata, and explicit skip reasons.

Paired-device acceptance must cover start, phone exercise navigation, strength/timed updates, rest expiry, background/foreground, disconnect/reconnect, finish, rapid restart, and idle reconciliation. Physical checks remain necessary for HealthKit permission/auto-launch, background delivery, wrist/haptic behavior, Lock Screen/Dynamic Island presentation, and signed installation/upgrade. Apple/Google sign-in and private email invitation acceptance require the separate release-access checks and test account. Until those pass, report iOS simulation and native contract results separately from complete phone-to-Watch E2E.

## Build observation

The first attempt in `/private/tmp/kotrana-review-evidence/ios-build.log` resolved dependencies and completed CocoaPods installation, then failed before compilation: `Watch companion app found. No simulator device ID has been set.` Flutter requires an explicit iOS simulator destination for this embedded Watch project. Retry with `flutter build ios --simulator --debug -d <IOS_SIMULATOR_UDID>` using a destination returned by `flutter devices`. This is a command/setup correction, not evidence of a native source failure; no pod pin or app change is indicated. The root task owns the retry and final build result. Package update notices are not build failures.
