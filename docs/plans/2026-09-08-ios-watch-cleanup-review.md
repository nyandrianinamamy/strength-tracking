# iOS and Watch cleanup plan

Status: implementation and local automated acceptance completed on 8 September 2026. Physical-device and signed distribution checks remain before a new release.
Current execution and test results: [implementation record](../reviews/2026-09-08-implementation-record.md).
The original verification record below describes the pre-repair baseline.

Changes made to support this review: native UI, emulator-auth and paired-Watch
tests; strict legacy UI assertions; two date-fixture corrections; expanded
Firestore rule checks; and one optional Firebase-options argument for testing
the real bootstrap against a demo project. Production defaults are unchanged.

## Baseline and scope

- Source: TestFlight tag `v1.0.31+309`, commit `e288c4984dc4ea9fe36468cd37fed64bdde42f47`.
- Branch: `codex/testflight-309-ios-watch-review`.
- Review date: 8 September 2026.
- Keep the iOS app, its embedded Live Activity extension, and the Watch companion. Keep the current private email invitation model unless separately changed.
- Keep Flutter, Riverpod, the training engine and body heatmap packages, local storage, Firebase Auth/Firestore, HealthKit, localization, iOS signing/release tooling, and their tests.
- Remove the Flutter web application and code used only by that application. Legal and support pages remain available because the iOS app links to them; they can be served as a small static site outside the app bundle.
- Local `main` includes later account, privacy, HealthKit, and web-removal work. Review useful patches individually; do not merge `main` wholesale into this release-based branch.

## Review findings

These are defects or concrete risks in the tagged source, not a claim that every execution path has been verified.

| ID | Priority | Finding | Evidence and proposed repair |
| --- | --- | --- | --- |
| A1 | P1 | First sign-in does not switch the persistence repository. | `app_bootstrap.dart` chooses memory storage for unsigned users. Onboarding and Settings construct a Firestore repository to load the account, but `replaceState` continues saving through the original provider. Bind repository ownership to the authenticated account and switch it before edits can occur. Test sign-in, edit, process restart, sign-out, and account switch against emulators. |
| A2 | P1 | The Firebase initialization fallback can throw again. | The catch path in `app_bootstrap.dart` returns `FirebaseAuth.instance` even if initialization failed before a default Firebase app existed. Make authentication availability explicit so local fallback can boot without Firebase. Test a cold startup with native Firebase initialization failure. |
| A3 | P1 | Account deletion can destroy training data before discovering that authentication is too old to delete the account. | `account_deletion_service.dart` calls `deleteUserData` before `deleteCurrentUser`; the current test explicitly exercises this partial failure. Reauthenticate before destructive work, retain recoverable local data until successful completion, handle provider cancellation, and invalidate saved training state. Review later commit `fb67be3` for reusable changes. |
| A4 | P2 | Failed saves have no recovery path visible to the user. | `app_state_controller.dart:25` updates memory, starts an unawaited save, and only logs failure. The Firestore repository writes the entire history and embedded exercise photos into one document. Add observable save status, durable retry/account ownership, and realistic history/photo size tests before deciding how to split storage. |
| M1 | P1 | Failed account switching leaves saves bound to a signed-out Firestore repository. | Bind account and repository together; transition safely to durable local state on failure and test subsequent edits/restart. |
| M2 | P1 | Offline fallback data can be discarded on the next online launch. | Separate initialization/access/transport failures, preserve account-owned local data until successful reconciliation, and test non-empty cloud plus offline edits. |
| M3 | P2 | Cached training and HealthKit state can cross account boundaries. | Scope derived state by account and invalidate it on transitions; test empty-history account switches too. |
| N1 | P1 | Delayed or duplicate Watch completion clears a newer workout. | `WatchSessionManager.swift` sends identity-free completion, including duplicate queued delivery when unreachable. Watch `WorkoutSessionManager.swift` applies it to the current session and clears state on an unscoped timer. Include session identity/revision, deduplicate, reject stale events, and scope/cancel delayed completion. |
| N2 | P2 | A restarted idle phone does not clear a cached Watch workout. | `watch_sync_service.dart` emits no idle state when both active session and its process-local last-sent ID are absent. Send authoritative idle state on initialization and sync requests. |
| N3 | P2 | Watch exercise selection does not follow phone updates. | `ExercisePageView.swift` initializes its selected page only in `onAppear`. Observe session/index changes while respecting an explicit manual-paging policy. |
| N4 | P2 | Rest notification work can outlive the workout. | `StrengthLiveActivityManager.swift` waits for authorization, then schedules using a previously calculated interval without checking current session state. Recheck identity/revision and the absolute deadline after every suspension. |
| N5 | P2 | French settings do not fully localize Watch and Live Activities. | Native strength/timed/rest/idle labels and parts of the Live Activity payload are hardcoded in English. Use consistent locale propagation and test both languages. |
| D1 | P2 | History reconstruction changes timed-workout fatigue. | `engine.dart:636` overwrites typed effort/local intensity while backfilling estimated RPE. Executed reproduction: the same cardio session produces fatigue 19.5877 live versus 50.1445 after history bootstrap. Preserve intensity fields and test replay equivalence. |
| D2 | P2 | Exercise swaps can merge two routine prescriptions. | The swap picker excludes only the current exercise; the controller permits a duplicate ID, but sets/timers are grouped by exercise ID. Reject duplicate swaps in both layers, matching the routine editor's constraint. |
| D3 | P2 | Adopted plans lose their superset execution semantics. | Planner adoption copies sets/reps/rest but drops `isSupersetPair`, so a preview shortened by paired rests becomes a longer ordinary workout. Either implement the promised execution or stop using unsupported supersets in time estimates. |
| D4 | P2 | Time-bounded plans keep the previous duration estimate. | `time_bounder.dart` changes exercises without updating `estimatedDuration`. Executed reproduction: actual recomputed duration 18 minutes while the result still reports 30. Recompute each adjustment and report infeasible time limits. |
| D5 | P2 | Personal-record rows can identify a recent weak set as the record. | `progress_service.dart:362` applies one rolling e1RM to every historical set and resolves ties by newest date. Separate current strength estimates from the historical record's set/date. |
| D6 | P2 | Archiving a built-in exercise does not exclude it from generated plans. | `planner_registry_adapter.dart` starts with all default exercises and skips archived records without removing the corresponding defaults. Exclude archived IDs before generation and adoption. |
| D7 | P2 | Saved engine state ignores changed exercise metadata and existing session content. | `training_engine_provider.dart:69` validates cached state with session IDs alone. Use a versioned content fingerprint or explicit reconstruction after relevant edits. |
| T1 | P2 | Existing E2E tests can bypass a broken UI. | The web workout scenario falls back to controller mutations when controls are absent. Remove these fallbacks; assert visible, tappable controls and the resulting persisted state. |
| T2 | P2 | Test results depend on the calendar date. | One engine and four dashboard tests query current readiness using March/April 2026 fixtures. Keep a coherent test reference time; retain the original assertions. Test-only corrections are part of this review branch. |
| C1 | P2 | Release upload is not gated by the app's full checks. | `build-ios.yml` builds and uploads directly. PR checks use a floating Flutter version and web E2E; neither establishes iOS/Watch acceptance for the release commit. Pin PR checks to the existing release toolchain and gate the exact commit before upload. |

Exact references are in [the app and infrastructure review](../reviews/testflight-309-app-review.md), [the domain review](../reviews/testflight-309-domain-review.md), and [the native review](../reviews/testflight-309-native-review.md).

## Removal inventory

| Action | Files or area | Preconditions |
| --- | --- | --- |
| Remove | Flutter entry point, manifest, icons and bootstrap configuration in `web/` | Move `privacy.html`, `terms.html`, and `support.html` to static hosting first; preserve their public URLs. |
| Remove/replace | `tool/ci/run_web_e2e.sh`, ChromeDriver setup, web E2E CI job | Preserve useful test scenarios in the native suite and prove it runs before retiring the old runner. |
| Simplify | `firebase.json`, `.github/workflows/firebase-deploy.yml`, Flutter platform metadata | Stop building/deploying Flutter web; retain Firestore rules, emulators, iOS Firebase config, and static legal hosting. |
| Remove | `external_url_opener_web.dart`, web force-update implementation/UI, browser notification implementation and web-only branches | Trace all callers. Use the existing native URL and Live Activity notification paths. Remove no-op wrappers only after callers are updated. |
| Remove | Direct `web`, `flutter_skill`, and `cupertino_icons` dependencies where the full reference inventory confirms no remaining use | `web` is browser-only here; the other two have no app imports in the tagged source. Re-resolve the lockfile without unrelated upgrades and check generated plugin registration. |
| Remove | 61 tracked `ios/build/` cache files (about 3.4 MB), tracked diagnostic output such as `firepit-log.txt` | Build caches are not source and are already ignored. Do not confuse them with assets, fixtures, signing configuration, or release screenshots. |
| Archive or remove from app source | `Screens/` HTML design exports, obsolete web plans, SideStore distribution metadata | Retain useful design/history outside the production source tree; verify any release consumers before removing SideStore metadata. |
| Simplify | Obsolete Watch `log_set`/`log_timed_set` forwarding, unused `weightIncrement` payload/cache fields, unused `activeRest` parameters and localization keys | Watch currently displays phone workouts; preserve that behavior. Test old cached snapshots and keep the fields actually used for rest rendering/haptics. |
| Remove after API review | Uncalled workout helpers `resumeActive`, `skipExercise`, `updateSessionNote`, `updateRpe`; unused load-recommendation providers and health-ingestion wrappers | Confirm production and test callers again after fixes. Test-only use does not automatically justify deleting a useful public package API. |
| Remove or document as retained API | Unused engine missed-session/dynamic-adjustment capabilities | They have package tests but no app callers. The app-only scope supports removing them if no external consumers exist; keep the algorithms the live planner uses. |
| Consolidate | Duplicated `StrengthLiveActivityAttributes.swift` | One shared source must belong to both Runner and Live Activity targets. Both still need the type. |
| Retain | Responsive layouts and iPad support | An iOS-only scope still includes iPad and resizable windows. A wide layout is not proof of web-only code. |
| Retain | `packages/training_engine`, `packages/flutter_body_heatmap`, generated localizations, Firebase access rules, tests | They are dependencies of the iOS product, not alternate apps. |
| Make reproducible | Runtime Lexend font loading and golden-test rendering | Bundle the fonts used by the app for fresh offline installs. Pin the golden renderer/font setup; inspect caption-only image differences before accepting new references. |

Do not remove exported package APIs, migration fields, archived exercises, or historical workout data merely because there are few references. Check persisted compatibility and runtime callers first. Do not manually prune transitive platform packages required by Dart's dependency resolution.

## Implementation sequence

1. **Establish the release baseline and reliable tests.** Complete static analysis, app/package tests, simulator build, strict iOS UI tests, native channel tests, and emulator access checks. Record failures separately from environmental limitations. The release already pins Flutter 3.41.9 and Xcode 26.3; align PR checks with those versions and gate upload on the same source commit. This machine initially has Flutter 3.41.4 and Xcode 27 beta. Remove tracked build caches and unused icon/debug dependencies after recording the baseline.
2. **Repair persistence and authentication.** Address A1–A4 and M1–M3, make account/repository ownership explicit, and prove fallback startup, offline reconciliation, failed account switches, and recoverable saves. Keep private invitations. Add regression tests before each fix.
3. **Repair workout and training calculations.** Address duplicate exercise swaps, cache invalidation, historical records, timed-session replay, planner consistency, and archived default exercises appearing in generated plans. Compare live updates, persistence, and reconstruction from history using the same fixtures.
4. **Repair native lifecycle behavior.** Address N1–N5 and add native tests for ordering, rapid restart, reconnect, idle reconciliation, and notification cancellation. Verify the actual Watch screen and Live Activity, not just a successful method call.
5. **Remove web and unused code in small changes.** Apply the inventory above after native scenarios are covered. Keep legal URLs operational. Run analysis and affected tests after each removal, then the full suite after the final dependency cleanup.
6. **Gate release.** Make checks required for the exact source commit, verify archive embedding/privacy/signing for Runner + Watch + Live Activity, and run physical-device acceptance. A new TestFlight build and tester distribution are separate actions after the plan and implementation are reviewed.

Each phase should be a small reviewable change with the original behavior/failure, repair, and test evidence recorded. Avoid a broad architecture rewrite while fixing specific defects.

## Acceptance matrix

| Surface | Required automated coverage | Additional acceptance |
| --- | --- | --- |
| Startup/access | Cold launch, allowlisted/denied login, profile completion, sign-out, account switch, failed Firebase startup | Apple/Google system login cancellation and real entitlement configuration |
| Persistence | Save/reload profile, exercises, routines, active/completed workouts; account isolation and error recovery | Actual terminated-process restart, signed-in offline cold start with non-empty cloud, failed account switches, cross-account derived-state isolation and reconnect behavior |
| Main iOS UI | Dashboard, all navigation tabs, settings, English/French, units/theme, iPhone and iPad layouts | Keyboard, accessibility labels, larger text and native image picker |
| Workout | Start, log strength/timed sets, edit/delete, rest, navigate exercises, resume, discard, finish, summary/history | Background/foreground, lock screen and timing |
| Routines/exercises | Create/edit/archive, routine groups and rotation; prevent duplicate slot corruption | Existing user data migration |
| Planner/progress | Generate/edit/adopt plan, prescription equivalence, history edits, PR identity, fatigue/cache reconstruction | No unverified health or recovery claims |
| Watch | Paired start/update/end, paging, reconnect, idle state, stale/duplicate message rejection, rapid new workout | First-use HealthKit permission, real Bluetooth reachability, background delivery and haptics |
| Live Activity | Actual activity state and notification scheduling/cancellation | Lock Screen/Dynamic Island rendering and permission prompts |
| Release | Pinned toolchain, all checks, archive validation and correct embedded targets | Device install and TestFlight processing/distribution confirmation |

The new native test harness uses isolated fixtures. A passing fixture-based UI test must not be described as proof of production Firebase bootstrap, real identity-provider login, Watch delivery, HealthKit readings, or physical-device behavior.

## Verification record

Initial tagged baseline: static analysis passed; app tests 220 passed / 4 failed; training-engine tests 477 passed / 1 failed. The five failures were stale fixture dates. After test-only corrections, all 224 app tests and all 478 engine tests pass.

The two heatmap golden tests fail by 468 pixels each (0.10%). Visual inspection of the generated diff places the differences at the FRONT/BACK caption glyph edges; the body drawing shows no differences. Reference images were not updated. Recheck with the pinned renderer before accepting a baseline change.

| Check | Result |
| --- | --- |
| Static analysis | Pass, no issues |
| App unit/widget tests | 224 passed |
| Training-engine tests | 478 passed |
| Firestore access rules | 10 passed against isolated emulators |
| iOS UI scenarios | All eight verified: seven passed together; the corrected group fixture passed a focused rerun |
| Native Watch/Live Activity channels | Two passed; channel acceptance does not prove presentation |
| Actual-bootstrap email tests | Three passed; one failed on A1, the confirmed lost-cloud-write defect |
| Heatmap goldens | Two caption-edge mismatches; references unchanged |
| Paired Watch acceptance | Real pairing/reachability, session receipt and exercise-update receipt verified; rapid session replacement timed out |
| Training replay diagnostic | Both assertions fail on the confirmed D1 and D4 defects |

The E2E runner continues through independent failures and records each suite's
exit code. Its aggregation, demo-plist restoration and simulator cleanup were
also verified with isolated stub commands. One development run was invalid as
an aggregate because the shell script changed while running; the individual
test logs above remain available. The final runner source is frozen and its
failure/cleanup contract was checked separately.

Tests and their boundaries are described in [the native coverage matrix](../ios-e2e-coverage.md). The baseline runner recorded app-ui FAIL (harness fault, corrected case rerun alone), native-wiring PASS, paired-watch FAIL (acceptance failure), and invite-auth FAIL (A1). A complete eight-scenario rerun remains required. Physical-device acceptance and the pinned release-toolchain run remain required; these results are not a release signoff.

The Watch screenshot showed a Health Access permission sheet during the
transport test. The replacement failure is therefore a failed acceptance check,
not an isolated runtime proof of N1's timer race. Resolve permission setup and
rerun before claiming Watch visual or lifecycle acceptance. The source-level
race and its required regression remain in the plan.

Saved evidence: [cloud-write failure](../../build/review-evidence/session/final-native/invite-auth.log),
[Watch checkpoints](../../build/review-evidence/session/paired-watch-final/checkpoints.json),
[routine-group rerun](../../build/review-evidence/session/ios-groups-final.log),
and [caption golden diff](../../build/review-evidence/heatmap-failures/male_heatmap_isolatedDiff.png).

## Review decision

Review the scope, ordered fixes, and removal inventory before implementation. Defaults are to keep private invitations, iPad support, Live Activities, Firebase, HealthKit, and static legal/support pages.


## Independent Fable 5.1 review (2026-09-08)

Reviewer: Claude Fable 5.1 (high reasoning), delegated from the main task.
Basis: the uncommitted state of worktree `.worktrees/testflight-309-ios-watch-review`
at `e288c4984dc4ea9fe36468cd37fed64bdde42f47`, the three review reports,
`docs/ios-e2e-coverage.md`, the saved logs under `build/review-evidence/session/`,
and direct reading of the cited Dart/Swift sources. No cleanup or production fix
was applied. The training replay diagnostic was re-executed; nothing else was
re-run.

### Verdict

The plan is accurate on its findings and honest about its evidence. All sixteen
product findings (A1–A4, N1–N5, D1–D7) are confirmed against the tagged source;
two are confirmed by executed reproduction (D1, D4), one by a real bootstrap
test failure (A1). The removal inventory is safe as written. The main gaps are
three unlisted persistence/account-isolation defects, one evidence-reporting
correction, and a few sequencing and test-harness changes listed below.

### Confirmed findings (source verified)

| ID | Status | Verification note |
| --- | --- | --- |
| A1 | Confirmed defect | `app_bootstrap.dart:57-58` selects `MemoryAppStateRepository`; `buildContainer` (`:137-147`) fixes it. `onboarding_screen.dart:82-91` and `settings_screen.dart:216-222` load from a throwaway `FirestoreAppStateRepository` and call `replaceState`, whose save (`app_state_controller.dart:25-31`) uses the fixed provider. `final-native/invite-auth.log:96-124` shows the exact failure: UI state `Cloud Edit`, cloud document still `Invited Athlete`. The fourth test (`signedIn: true`) passes, which isolates the fault to repository selection rather than the Firestore write path. |
| A2 | Confirmed defect, scope understated | `app_bootstrap.dart:127` reads `FirebaseAuth.instance` in the catch path. See "Missing issues" M2: the same catch block also swallows network/Firestore failures for a signed-in user. |
| A3 | Confirmed defect | `account_deletion_service.dart:13-15`; `settings_screen.dart:328-336` wires `deleteUserData` before `deleteCurrentUser`. `auth_service.dart:77-83` performs no reauthentication. The existing test (`account_deletion_service_test.dart:22-36`) codifies the destructive order. |
| A4 | Confirmed | `app_state_controller.dart:27-31`; `app_state_repository.dart:96-98` writes the whole state to one document. |
| N1 | Confirmed defect | `WatchSessionManager.swift:65-67` sends an identity-free `session_end`; `:163-165` always sends a second copy via `transferUserInfo` even when the direct message succeeded, so a duplicate end is the normal case, not an edge case. Watch `WorkoutSessionManager.swift:124-135` clears snapshot and cache after 3 s with no cancellation; `session_update` (`:112-117`) does not cancel a pending clear. |
| N2 | Confirmed | `watch_sync_service.dart:84-94`. |
| N3 | Confirmed | `ExercisePageView.swift:42-44`. |
| N4 | Confirmed | `StrengthLiveActivityManager.swift:156-176`: interval computed before `await requestAuthorization`, no session recheck before `add`. |
| N5 | Confirmed | Hardcoded strings at the cited Swift lines and `StrengthLiveActivityManager.swift:166-167`. |
| D1 | Confirmed by execution | Re-ran `tool/review/verify_training_replay.dart`: `directFatigue 19.5877`, `replayedFatigue 50.1445`, exit 1. Cause at `engine.dart:636-646` (rebuilds `LoggedSet` with legacy `rpe` only). |
| D2 | Confirmed | `active_workout_screen.dart:658-661`, `workout_controller.dart:313-318`. |
| D3 | Confirmed | `smart_planner_controller.dart:338-348`; `RoutineExercise` has no superset field. |
| D4 | Confirmed by execution | Same diagnostic: stored 1800 s, recomputed 1080 s. `time_bounder.dart:87-91,115-119,141-143`; `PlannedSession.copyWith` retains the estimate. |
| D5 | Confirmed | `progress_service.dart:362-390`. |
| D6 | Confirmed | `planner_registry_adapter.dart:10-18`. |
| D7 | Confirmed | `training_engine_provider.dart:66-75`. |
| T1 | Confirmed | Fallback branches removed in the `app_test.dart` diff; the file is a web suite slated for removal, so its value is short-lived. |
| T2 | Confirmed | Fixture edits keep the original assertions. |
| C1 | Confirmed, with correction | See "Corrections" C-a. |

### Missing issues

These are not in the plan. M1–M3 are confirmed by source reading; none was executed.

- **M1 (P1, persistence/account isolation) — failed account switch leaves a
  dead repository.** `settings_screen.dart:196-241` (`_signInAndReplace`): if
  `requireAllowed` throws after the replacement sign-in succeeded, the catch
  calls `signOut()`. The long-lived `FirestoreAppStateRepository` then throws
  `StateError('No authenticated user')` on every save (`app_state_repository.dart:73-77`),
  each failure is only logged (A4), the screen keeps showing the previous
  account's data, and the next launch boots signed-out into an empty memory
  repository. Every edit made after the failed switch is lost. Fold into the A1
  repair: bind repository and account together and treat a failed switch as an
  explicit "signed out, local-only" state.
- **M2 (P1, data loss) — the bootstrap catch block discards offline edits.**
  `app_bootstrap.dart:40-107` catches every exception, including a Firestore
  `unavailable` from `requireAllowed` or `repository.load()` when a signed-in
  user starts offline without a cached document. The app then runs on
  `SharedPreferencesAppStateRepository` while still signed in. On the next
  successful start, `:81-90` migrates that local data only if the cloud
  document is empty and unconditionally removes the local key. A user who
  trains offline after such a start loses those sessions. The A2 repair must
  separate "Firebase is unavailable" from "auth is unavailable", keep the local
  data until a merge decision is made, and add an offline cold-start test for a
  signed-in user with non-empty cloud state.
- **M3 (P2, account isolation) — derived engine state is device-scoped.**
  `SharedPreferencesTrainingEngineStateRepository` uses the fixed key
  `training_engine_state_v1` (`training_engine_state_repository.dart:15`) with
  no user ID, and nothing clears it on sign-out (`settings_screen.dart:251-299`),
  account switch, or deletion. `loadTrainingEngine` rebuilds when session IDs
  differ but `_preserveHealthKitState` (`training_engine_provider.dart:79,160-173`)
  copies the previous account's sleep and HRV histories into the new account's
  engine, and two accounts with zero sessions share the restored state outright.
  Scope the key by UID or clear it on every account transition; add the case to
  the phase 2 tests.
- **M4 (P3, product/acceptance) — Watch HealthKit prompt on first session.**
  `WorkoutSessionManager.swift:243-268` requests HealthKit share authorization on
  every `session_update` until a session exists, so a first workout on a fresh
  Watch shows the Health Access sheet over the workout (this is what the paired
  screenshot shows). Not a defect, but the acceptance matrix should list the
  prompt and the disposable-Watch runner must pre-grant or dismiss it.

### Corrections to the prior review

- **C-a (C1 wording).** `.github/workflows/build-ios.yml:23-29` already pins
  Xcode 26.3 and Flutter 3.41.9 (that is commit `e288c49`, the tagged baseline).
  The gap is the missing test/analyze gate in that workflow and the floating
  Flutter in `pr-checks.yml:18-21`. Rephrase C1 and step 1 as "pin PR checks to
  the release toolchain and gate upload on them", not "pin the release toolchain".
- **C-b (verification record).** The final aggregated runner recorded
  `app-ui FAIL`, `native-wiring PASS`, `paired-watch FAIL`, `invite-auth FAIL`
  (`final-native/results.tsv`), exit 1. The plan's table reads as mostly green.
  State the aggregate result and classify each failure: invite-auth = product
  defect A1; app-ui = test-harness fault (`Iterable.last` on an empty finder in
  `revealUi`, `final-native/app-ui.log:96-124`), fixed and rerun in isolation;
  paired-watch = acceptance/environment. The eight-scenario suite has not been
  run together since the group fixture was corrected; do so before calling the
  suite green.
- **C-c (paired Watch failure signature).** The driver reported `different state`
  (`paired-watch-final/result.json`), which means the Watch cache held a
  snapshot that never matched session B during 25 s. The N1 race would instead
  leave the cache empty (`idle/missing cache`) after B was cached and then
  cleared. So the run did not exhibit N1 at all; it is most consistent with B's
  `session_update` never being applied while the permission sheet was up. The
  plan's caution is correct; add this detail so nobody reads it as a partial N1
  reproduction. Also change `test_driver/paired_watch_driver.dart:226-231` to
  include the last observed summary in the error; the current message discards
  the evidence needed to distinguish these cases.
- **C-d (in-flight save attribution).** The plan's phase 2 goal "prevent
  in-flight saves from being attributed to another account" is already mostly
  mitigated: `_doc` resolves `auth.currentUser` synchronously at `save()` entry
  (`app_state_repository.dart:73-77`), so a save started under account A cannot
  land in account B's document. The real cross-account risks are A1, M1, and M3.

### Removal safety

Verified against the tagged tree:

- `ios/build/`: 61 tracked files, 3,403,104 bytes. Safe to untrack.
- `web` package: imported only by `external_url_opener_web.dart`,
  `force_update_web.dart`, `rest_timer_notification_service_web.dart`, each
  reached through a `dart.library.js_interop` conditional import. Remove the
  three files, collapse the three conditional imports, then drop the dependency.
- `cupertino_icons`, `flutter_skill`: zero references under `lib/`, `test/`,
  `integration_test/`. Safe.
- `resumeActive`, `skipExercise`, `updateSessionNote`, `updateRpe`,
  `loadRecommendationProvider`: defined only; no callers. `engineWeightSuggestionProvider`
  is used by two test files only. Safe after migrating those tests.
- `kIsWeb` appears in nine files; each branch is a simplification, not a
  removal precondition. `firebase_options.dart` keeps a web app entry in
  `firebase.json`; remove the web configuration from both when dropping web.
- `firebase.json` hosting serves `/privacy`, `/terms`, `/support` from
  `build/web`, the Flutter web output. After web removal the static pages need a
  new hosting `public` directory and the three rewrites must survive; the plan
  already requires this. The `**` → `index.html` rewrite should be deleted.
- `pubspec.yaml:2` still describes the product as "for iOS and the web"; update
  during cleanup.
- Deployment targets: `project.pbxproj` carries `13.0` (×3) and `16.2` (×3),
  Podfile `15.0`. The simulator build only succeeded with the test-only
  `IPHONEOS_DEPLOYMENT_TARGET = 16.2` override. Reconcile in the project before
  the pinned release gate, as the native review says; do not do it inside a
  removal commit.

Nothing in the inventory removes persisted fields, migration code, archived
records, or the invitation model. The retain list (iPad, heatmap, engine,
Live Activity, legal pages) is correct.

### Priorities and sequencing

- Keep A1, A3, N1 at P1. Raise M1 and M2 to P1 and fix them with A1/A2 in
  phase 2; they share the same repair (repository/account binding and explicit
  offline state). Add M3 to phase 2 as well.
- Move the zero-risk removals (untrack `ios/build`, drop `cupertino_icons` and
  `flutter_skill`, delete `firepit-log.txt`) into phase 1 after the baseline is
  recorded. They shrink the diff for every later review and cannot regress
  behavior.
- Keep web removal after phase 4 as planned. `app_test.dart` disappears with
  it, so do not invest further in that file beyond what is already done.
- D2 and D6 are user-visible corruption of active or generated routines; keep
  at P2 but schedule them first within phase 3. D1/D4 already have a runnable
  invariant (`tool/review/verify_training_replay.dart`); turn it into package
  tests before fixing so the expected values are locked.
- A2 fix must land before A1 tests can meaningfully cover the offline case.

### Test evidence assessment

| Claim | Assessment |
| --- | --- |
| 224 app tests, 478 engine tests, analyzer clean | Verified from `flutter-test-final2.log`, `engine-test-final.log`, `analyze-final2.log`. |
| 10 Firestore rule checks | Verified from `firestore-rules.log`. They are REST checks against the emulator with the real rules, run on non-default ports. Adequate for access isolation; they do not test the client SDK's offline behavior. |
| Eight native UI scenarios | Seven passed in one run; the eighth failed in that run on a harness fault, then passed alone after the test was edited. Rerun the full file. The suite exercises real widgets, router, controllers and SharedPreferences, but its `_FixtureUser` and fixture auth service mean it says nothing about production bootstrap (as the coverage doc states). |
| Actual-bootstrap auth: 3 pass, 1 fail | Verified. The failing assertion is the A1 reproduction. The suite bypasses `main`, so Live Activity/Watch startup and the SharedPreferences migration path (`app_bootstrap.dart:81-90`) are not covered. |
| Two native channel tests | Verified from `results.tsv`. As the native review notes, `StrengthLiveActivityManager.swift:145-149` uses `try?` on `Activity.request`, so this cannot detect a failed Activity. |
| Paired Watch: start and exercise receipts verified, replacement timed out | Verified from `checkpoints.json` and receipts. See C-c for what the timeout does and does not show. |
| Heatmap goldens | Verified: 468 px, 0.10% each. Caption-edge differences under Xcode 27 beta/Flutter 3.41.4 are consistent with a font-rendering delta; keep references unchanged until the pinned toolchain run. |
| Runner contract | `runner-contract-check.txt` covers aggregation, plist restore and simulator cleanup with stubbed commands; `git status` confirms `GoogleService-Info.plist` is restored. Adequate for the runner; not evidence about the app. |
| Toolchain drift | Flutter 3.41.4/Xcode 27.0 beta (`flutter-version.txt`, `xcode-version.txt`) versus release 3.41.9/Xcode 26.3, plus a deployment-target override. All runtime results are indicative only until repeated on the pinned toolchain. |

The evidence supports every source-level finding, the confirmed app-bootstrap
runtime defect (A1), and the two training-engine defects reproduced by
execution (D1, D4). It does not support any statement that the app, Watch, or
Live Activity is verified; the plan already says so, and this review agrees.

### Recommended plan changes

1. Add M1, M2, M3 to the findings table (P1, P1, P2) and to phase 2 with the
   tests named above; add M4 to the acceptance matrix under Watch.
2. Rewrite C1 and step 1 per C-a.
3. In the verification record, state the aggregate runner outcome
   (`3 of 4 suites FAIL`, exit 1) and classify the three failures per C-b.
4. Add the `different state` interpretation (C-c) to the paired-Watch paragraph
   and make the driver log the last observed summary.
5. Require a full eight-scenario `ios_app_test.dart` run and a pinned-toolchain
   run of every suite before phase 6; record both in the table.
6. Move the zero-risk removals into phase 1; keep web removal in phase 5.
7. Add offline cold start (signed-in user, non-empty cloud, no cache) and
   cross-account engine-state isolation to the Persistence row of the
   acceptance matrix.
8. Add "update `pubspec.yaml` description, `firebase.json` web app entry, and
   the `**` rewrite" to the web-removal inventory row.

### Remaining validation requirements

Unchanged from the plan, plus: pinned-toolchain reruns of all suites; the full
native UI suite in one run; offline cold-start and account-switch failure tests
after the phase 2 repair; a paired-Watch run with HealthKit permission
pre-granted; physical-device checks for Watch delivery, Live Activity
presentation and rest notifications. No TestFlight build should be produced
from this branch before phases 2–4 are complete and the gate in phase 6 exists.
