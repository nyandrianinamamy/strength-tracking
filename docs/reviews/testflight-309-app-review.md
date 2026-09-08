# TestFlight 309 app and infrastructure review

Baseline: `v1.0.31+309` / `e288c4984dc4ea9fe36468cd37fed64bdde42f47`.
Reviewed startup, repositories, account/onboarding/settings flows, router, shared
app services, platform-specific wrappers, Firebase rules, dependencies and CI.
Domain and native reviews cover the remaining product subsystems.

## Findings

### A1 — P1: first sign-in does not change the repository used for saves

`lib/src/core/app_bootstrap.dart:55-56` selects an in-memory repository for the
signed-out launch; `:135-143` fixes that repository in the container overrides.
`lib/src/features/onboarding/onboarding_screen.dart:84-91` creates a cloud
repository only to load the signed-in state. It then calls `replaceState`, whose
save at `lib/src/core/app_state_controller.dart:25-30` still uses the original
repository. Settings repeats the load/replace pattern at
`lib/src/features/settings/settings_screen.dart:216-222`.

An invited user can sign in successfully and edit a workout/profile while those
changes remain in memory. Restarting selects Firestore and discards those edits.
The new emulator UI test asserts that an edit after sign-in reaches Firestore;
its run status is recorded in the plan, separately from this source finding.

Repair repository selection and account ownership as one operation, with tests
for first sign-in, account switch, failed switch, sign-out, and restart. Do not
adopt optional-account behavior from newer `main` as an incidental repair.

### A2 — P1: cold Firebase failure can break the fallback

`lib/src/core/app_bootstrap.dart:105-125` catches initialization failure and
loads local state, then accesses `FirebaseAuth.instance` again. If Firebase
failed before creating a default app, that access also throws. `main` does not
catch the second failure and has only rendered the loading screen.

Model authentication as unavailable when initialization fails; construct a
working local container without reading a nonexistent default Firebase app.
Test the cold failure, not only an injected auth object or an already configured
Firebase process. Local JSON corruption also needs an explicit recoverable
startup error instead of repeatedly attempting the same failing load.

### A3 — P1: account deletion destroys data before reauthentication

`lib/src/features/settings/account_deletion_service.dart:14-16` deletes data,
then deletes the auth account, then clears memory. The second operation can fail
with a recent-login requirement after remote training data is already gone.
`test/features/settings/account_deletion_service_test.dart:28` reproduces this
ordering with an error but treats it as expected behavior.

Reauthenticate before deletion, handle cancellation without mutation, keep a
recoverable state through partial failure, and clear persisted derived engine
state when deletion completes. Reuse the appropriate parts of later commit
`fb67be3`, after checking its dependencies on optional-account changes.

### A4 — P2: save errors leave an apparently successful UI

`lib/src/core/app_state_controller.dart:25-30` updates memory immediately and
only logs failures from the unawaited save. The user has no save status, retry,
or error recovery. `lib/src/data/repository/app_state_repository.dart:96-98`
writes the entire state to one Firestore document, including all sessions and
base64 photos from `lib/src/data/models/exercise.dart:85`.

Test permission loss, offline recovery, concurrent clients, and realistic
history/photo sizes. Add observable durable save/retry behavior with account
ownership before choosing a storage migration. This review has not measured the
current production document size and does not claim a live quota failure.

### T1/T2/C1 — test and release gaps

- Legacy workout E2E conditionally mutated controllers when UI interactions
  failed. The review branch removes those fallback paths.
- Five baseline readiness test failures were date-dependent fixtures. The
  review branch aligns query and fixture time; assertions remain unchanged.
- `.github/workflows/pr-checks.yml` uses floating Flutter and web E2E on Linux.
  `.github/workflows/build-ios.yml` uploads without a test prerequisite. Gate
  the release commit with pinned app/package, iOS and native checks.
- The installed Flutter 3.41.4/Xcode 27 beta differ from release Flutter
  3.41.9/Xcode 26.3. The first Xcode build rejected old deployment targets;
  a temporary `XCODE_XCCONFIG_FILE` override to iOS 16.2 allowed the simulator
  build. That override is verification setup, not a release configuration fix.

## Scope boundaries

The tagged repository has iOS and web platform roots; it does not contain an
Android or macOS desktop application to remove. iPad/wide layouts remain iOS
features. The static legal URLs in `lib/src/core/legal_links.dart` still need
their HTML pages after Flutter web removal.

Direct dependency reference search found no app imports for `flutter_skill` or
`cupertino_icons`; `web` is referenced by browser implementations. Treat removal
as a checked dependency change, including generated registration and lockfile
validation. The training engine, heatmap, image picker, connectivity, auth,
storage, HealthKit and localization packages are used by the iOS app.

## Verification boundaries

Source inspection and tests support the specific findings above. They do not
prove real Apple/Google sign-in, production allowlist configuration, App Store
privacy answers, HealthKit device data, or every background interaction. The
review uses demo emulators and disposable simulators, not production accounts.
