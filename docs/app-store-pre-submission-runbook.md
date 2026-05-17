# App Store Pre-Submission Runbook

Use this runbook to finish Kotrana App Store Connect readiness without submitting the app for App Review.

## Current Release Candidate

- Release tag: `v1.0.31`
- Tagged commit: `ba9d896`
- Expected uploaded build from the current tag: `1.0.31 (286)`
- App Store version page to update: `1.0`
- Release mode: manual release after App Review approval

Do not infer the App Store build number from `main`. Documentation-only commits may advance `main` and auto-bump `pubspec.yaml`; the release build comes from the `v1.0.31` tag unless the tag is intentionally moved again.

## Stop Boundary

Allowed:

- Enable required Apple Developer capabilities.
- Build and upload the tagged app to TestFlight/App Store Connect.
- Upload or manually enter metadata, screenshots, review information, privacy answers, pricing, availability, age rating, and declarations.
- Select the processed build on the App Store version page.
- Save the App Store version page in a ready-to-submit state.

Not allowed for this goal:

- Click `Add for Review`.
- Submit the app for App Review.
- Enable automatic public release.

## External State

### Firebase Auth Providers

Read-only Firebase Auth config checks on 2026-05-17 verified:

- Email/password sign-in is enabled with password required.
- Default Google provider `google.com` is enabled.
- Default Apple provider `apple.com` is enabled.

The check used the Identity Toolkit Admin API with `x-goog-user-project: myappv4`. Do not paste the raw API response into docs or logs because provider responses can include sensitive OAuth/client material.

### Reviewer Access

Read-only release access checks on 2026-05-17 verified:

- `allowedEmails/app-review@mamy-r.dev` exists, is enabled, and has role `reviewer`.
- `allowedEmails/ramiasamananaando5@gmail.com` exists, is enabled, and has role `user`.
- `allowedEmails/nyandrianinamamy@gmail.com` exists, is enabled, and has role `admin`.
- Firebase Auth contains exactly one reviewer account for `app-review@mamy-r.dev`.
- The reviewer account has seeded Firestore demo state with exercises, routines, a routine group, and completed sessions.

Re-run without printing tokens or reviewer passwords:

```bash
KOTRANA_FIREBASE_ACCESS_TOKEN="$(gcloud auth print-access-token)" dart run tool/verify_release_access.dart
```

### Apple Developer Capability

Read-only capability check workflow run `25989507219` passed on 2026-05-17 after Team Admin enabled Sign in with Apple for `dev.mamy-r.kotrana`.

Manual `Build iOS` workflow run `25989519652` checked out release tag `v1.0.31` at `ba9d896` and successfully uploaded the signed IPA to App Store Connect/TestFlight. The expected uploaded build is `1.0.31 (286)`.

The workflow uses `skip_waiting_for_build_processing`, so App Store Connect build processing must still be confirmed before selecting the build on the version `1.0` page.

### Metadata And Screenshots

Manual `Sync App Store Metadata` workflow run `25989760214` succeeded on 2026-05-17 with `build_version=1.0` and `upload_screenshots=true`.

The run uploaded metadata and App Review information, confirmed the five iPhone 6.9-inch screenshots are present, and passed Fastlane precheck with `precheck_include_in_app_purchases: false`.

## Manual App Store Connect Checklist

Fill or verify these fields before stopping:

- App information: name, subtitle, categories, content rights.
- Pricing and availability: free, all countries/regions, Mac availability off, Vision Pro availability off, manual release.
- iOS version metadata: promotional text, description, keywords, support URL, privacy URL, copyright, optional blank marketing URL.
- App Review information: contact, reviewer login email, real reviewer password, review notes.
- Build: select the processed `1.0.31 (286)` build uploaded by workflow run `25989519652`.
- Screenshots: the five prepared iPhone 6.9-inch screenshots in `ios/fastlane/screenshots/en-US`.
- Age rating: health/wellness yes; medical/treatment no; no web access, user-generated public content, messaging, ads, gambling, violence, sexual content, drugs, alcohol, horror, profanity, or crude humor.
- Regulated medical device: no.
- App Privacy: disclose email, Firebase UID/account identifier, workouts/routines/progress/readiness/training data, optional Apple Health-derived sleep/HRV/resting heart rate, and optional exercise/machine photos; use is app functionality only; no tracking or third-party advertising.
- Accessibility labels: leave unclaimed unless verified against the release build.

## Verification Evidence Already Collected

The latest local readiness pass completed successfully:

- `flutter analyze --no-fatal-infos`
- `flutter test`
- `cd packages/training_engine && dart test`
- `firebase emulators:exec --only auth,firestore --project myappv4 "dart run tool/verify_firestore_rules.dart"`
- `KOTRANA_FIREBASE_ACCESS_TOKEN="$(gcloud auth print-access-token)" dart run tool/verify_release_access.dart`
- `flutter build ios --release --no-codesign`
- `bash tool/ci/run_web_e2e.sh`
- `flutter test test/core/release_ios_metadata_test.dart test/core/release_version_test.dart` verifies release version, iPhone-only release targeting, HealthKit/Bluetooth entitlement hygiene, and the five `1290 x 2796` iPhone 6.9-inch screenshots.
- Fastlane syntax check
- App Store metadata workflow YAML parse
- Build iOS workflow YAML parse
- Fastlane screenshot validation for five screenshots
- Live legal URLs returned `200` for `/privacy`, `/terms`, and `/support`
- `gh workflow run "Check App Store Capability"` -> run `25989507219` passed
- `gh workflow run "Build iOS" -f release_tag=v1.0.31` -> run `25989519652` uploaded `v1.0.31`
- `gh workflow run "Sync App Store Metadata" -f build_version=1.0 -f upload_screenshots=true` -> run `25989760214` passed

Re-run the relevant checks after changing code, metadata automation, screenshots, entitlements, Firebase rules, or release workflows.
