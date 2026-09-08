# iOS and Watch test coverage

Baseline: `v1.0.31+309`. This branch retains the iOS app, Watch companion and Live Activity extension. The coverage below describes implemented assertions; it does not establish that the current native runs pass. Recorded verification results belong in [the implementation record](reviews/2026-09-08-implementation-record.md).

## Run

On macOS with Flutter 3.41.9, Xcode, iOS/watchOS runtimes, Firebase CLI, Java and AXe:

```bash
flutter pub get
AXE_PATH=/absolute/path/to/axe tool/ci/run_ios_e2e.sh --with-auth --paired-watch
```

CI pins Xcode 26.3 and installs `xcodebuildmcp@2.7.0`, which bundles AXe 1.8.0. The runner creates an isolated phone/Watch pair and deletes only those devices on exit. For an existing disposable pair, set `IOS_E2E_SIMULATOR_UDID` and `WATCH_SIMULATOR_UDID`; those devices are retained. `IOS_E2E_RUNTIME` and `IOS_E2E_DEVICE_TYPE` select another installed runtime/device.

To run the same eleven UI scenarios on an iPad:

```bash
IOS_E2E_DEVICE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-4th-generation-8GB \
  IOS_E2E_OUTPUT_DIR="$PWD/build/ios-e2e-ipad" \
  tool/ci/run_ios_e2e.sh --ui-only
```

`--ui-only` runs `ios_app_test.dart` and then exits with that suite's result. It skips native channel wiring, paired Watch, auth, startup and process-restart suites; it cannot be combined with `--with-auth` or `--paired-watch`. Firebase CLI, Java and AXe are not needed for this mode. CI runs the iPad step only when the manual Build iOS workflow sets `run_ipad=true`. Set `quality_only=true` as well to verify without uploading. Normal tags and PRs require the full iPhone/Watch suite; iPad compatibility is optional. When enabled, CI uploads `build/ios-e2e-ipad/` alongside the phone/Watch evidence.

The iPad run uses the app's existing iPhone-compatible mode (`TARGETED_DEVICE_FAMILY=1`).

The runner temporarily replaces the bundled Firebase plist with a demo configuration and restores the source on exit. Do not build concurrently in that checkout or distribute its test binaries. The runner targets simulators; paired acceptance also verifies native device identity before proceeding. Auth/Firestore use only `demo-kotrana-e2e`, with emulator ports 19099 and 18081. No production access data is seeded.

The runner stops at the first failing suite, preserving its log and exit code in `results.tsv`. A successful full run must pass Firestore rules, combined phone acceptance, paired Watch and process restart. Logs, toolchain versions, simulator identities, source commit and working-tree status accompany the results.

The normal phone run builds three test applications:

1. `ios_acceptance_test.dart` groups all phone UI, native wiring, invitation/auth and startup assertions in one build. Suite hooks remain group-scoped. These tests use a shared test-only preference prefix and clear their data as before; emulator connections are configured once per process.
2. `paired_watch_test.dart` uses its dedicated host driver for Watch receipt/UI checks. The phone continues pumping foreground frames while awaiting the host.
3. `ios_persistence_restart_test.dart` selects write/read at runtime through the host driver. After verified process termination, the read launch uses the exact same prebuilt app, with no second build or read-phase seeding.

Dependencies are resolved before the runner. Every Flutter test/drive invocation uses `--no-pub`; all Firebase-backed suites share one emulator lifetime. Individual source suites remain directly runnable for diagnosis, and the optional iPad mode still runs the eleven UI scenarios alone.

## Coverage and boundaries

| Suite | Required assertions | Boundary |
| --- | --- | --- |
| `ios_app_test.dart` | 11 UI scenarios: invitation entry, profile, exercise/routine CRUD, strength/timed workouts, summaries/progress, resume/discard, groups/rotation, planner/adoption, preferences and destructive-action dialogs | Production router/widgets/controllers and native local storage; isolated auth and HealthKit disabled |
| `ios_invite_auth_test.dart` | Missing/disabled invitation rejection, invited login and cloud writes, signed-in bootstrap, denied switch preserving prior cache, cached offline edits, uncached offline admission and visible navigation after reconnect, account deletion cancellation/reauthentication | Real Firebase SDK and production bootstrap/account repositories against demo emulators; email identity |
| `ios_startup_test.dart` | Loading screen, guest restoration after injected Firebase initialization failure, actual invitation login/profile persistence, automatic native service startup | Calls the same launch helper as production `main`; byte-forward observers retain real Watch/Activity native responses; injected failure is not a real OS outage |
| `ios_persistence_restart_test.dart` | Write phase logs an offline workout; host terminates the app; read phase restores native Firebase identity and exact active set, then reconciles cloud | Two real processes, same sandbox/emulator session; read phase never reseeds or signs in |
| `native_runtime_wiring_test.dart` | Real method channels; actual ActivityKit activity identity, updated content and removal | Simulator runtime state, not visual Lock Screen/Dynamic Island acceptance |
| `paired_watch_test.dart`: transport scenario + host driver | Actual paired delivery, exercise advance, new workout surviving an earlier end, settled idle; received cache plus visible Watch text and settled permission state | Sends fixtures through real native channels to the companion process; UI permission actions use the observed accessibility tree |
| `paired_watch_test.dart`: production app scenario + host driver | Start from the dashboard, log a strength set, finish through UI; matching Watch receipt/text and ActivityKit content at each stage; Watch idle and Activity removal after finish; exact completed workout reloaded from native local storage | Calls the same launch helper as production `main`, with real services and durable guest storage; seeded library, injected Firebase failure, phone HealthKit disabled and zero rest intervals; persistence read occurs in the same app process |
| App and engine unit/widget tests | Account ownership/outbox conflicts/capacity, deletion ordering, cache isolation, swaps, planner duration/adoption, replay equivalence, archived exercises, PR identity, UI regressions | Deterministic focused behavior; no external identity providers or Bluetooth |
| Native Swift tests | Message ordering, stale/duplicate/reinstall handling, selection policy, scoped completion/rest cancellation and locale labels | Shared pure native logic; runtime acceptance is covered separately above |
| Firestore rules verifier | Ten allowlist and ownership checks | Local emulators with production rules |
| Heatmap goldens | Exact male/female body images at a fixed viewport, with semantic front/back labels in the fixture | Pinned host Flutter renderer; no fixture font dependency or pixel tolerance |

The UI suite uses bounded waits and requires hit-testable controls. It never replaces failed interactions with controller mutations. Lexend fonts and their license are bundled, so a fresh install does not download typography.

The production app scenario uses the restored guest profile `Paired App Athlete`. It taps `START SESSION`, logs 80 kg × 6 at RPE 8 for `Flow Bench Press`, and finishes through the workout UI. The assertions read state without replacing those interactions with controller calls. The Watch must display the exercise, then `80 kg x 6`, then `No active workout`. The actual ActivityKit activity must carry the same session ID, exercise and set progress, then disappear with no pending rest notification. Reloading SharedPreferences must yield that completed session and its exact set, with no active session. The separate process-restart suite covers recovery after host termination.

The paired driver installs the built Watch companion after Flutter installs the phone app. If first-install Watch registration is not yet reachable, it performs at most two relaunches before the strict deadline. Snapshot and idle checkpoints record receipt, accessibility captures and screenshots of both simulators.

The AX helper requires two consecutive captures of the expected visible text and no unresolved permission sheet. On the recognized Kotrana Health Write Access form, it explicitly selects the requested Workouts permission on the supplied disposable Watch. It prefers the fully visible Workouts checkbox, or uses `All Requested Data Below` on the captured top form; the native request currently contains only Workouts write access. Every switch tap must be followed by a fresh capture showing `AXValue` `1`. The specific Workouts checkbox must show `1` before Done is submitted. Controls beneath the fixed header are scrolled into view before tapping. Switch and Done taps use centers derived from their validated live frames; Review retains its semantic label tap. Unknown, ambiguous or unconfirmed controls fail with evidence. No preference or permission database is written directly.

After the UI check, the host driver separately requires the native Health callback state to be settled: authorization is denied (`1`) or granted (`2`), and pending is false. A closed sheet or visible workout alone cannot satisfy that check. An existing settled denial remains compatible with the core workout flow; selecting the checkbox does not substitute for observing the native outcome.

## Remaining device acceptance

Automated coverage does not establish real Apple/Google login, Bluetooth/background delivery, first-use HealthKit permission behavior on a physical device or actual HealthKit histories, notification/haptic timing, Lock Screen/Dynamic Island rendering, system image-picker behavior, or accessibility at all text sizes. These require device acceptance before distribution. The Watch currently uses an `HKWorkoutSession` for session/background behavior; it has no workout builder or saved-workout export path.

The checked-in workflow pins the release toolchain and gates upload on the verified source SHA. A local run on another Xcode version does not prove the pinned GitHub job, signing, archive distribution or TestFlight processing. Build a normal production configuration again after simulator testing.

Each runner output includes `timings.tsv` with setup and suite wall times. CocoaPods dependencies are cached by platform, architecture, Xcode/Flutter version and lockfiles; the release job restores the cache populated by successful verification. `pod install` still runs to validate the restored dependencies. No application build or signing data is cached. A first run can be cold, and GitHub's cache ref restrictions mean separate release tags do not automatically share caches.
