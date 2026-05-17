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

## External Blockers

### Apple Developer Capability

The latest tagged iOS build failed before archive in GitHub Actions run `25988195896`, job `76389454500`, because the current App Store Connect API key cannot enable `APPLE_ID_AUTH` for `dev.mamy-r.kotrana`.

Manual Team Admin step:

1. Open Apple Developer > Certificates, Identifiers & Profiles.
2. Open identifier `dev.mamy-r.kotrana`.
3. Enable `Sign in with Apple`.
4. Save the identifier.

After this, rerun the tagged build using either path:

```bash
gh workflow run "Build iOS" -f release_tag=v1.0.31
```

or rerun failed workflow `25988195896` from GitHub Actions.

The `Build iOS` workflow checks out the tag for manual runs, so it builds `v1.0.31`, not the tip of `main`.

### Metadata Permission

The latest metadata run `25964706927` authenticated, found App Store version `1.0`, and loaded the local metadata files, then failed because the API key cannot edit App Store metadata.

Use one of these paths:

1. Replace/update the `APP_STORE_CONNECT_*` GitHub secrets with an API key that can edit metadata, then run:

```bash
gh workflow run "Sync App Store Metadata" -f build_version=1.0 -f upload_screenshots=true
```

2. Fill App Store Connect manually from `docs/app-store-connect-submission-values.md` and upload screenshots from `ios/fastlane/screenshots/en-US`.

## Manual App Store Connect Checklist

Fill or verify these fields before stopping:

- App information: name, subtitle, categories, content rights.
- Pricing and availability: free, all countries/regions, Mac availability off, Vision Pro availability off, manual release.
- iOS version metadata: promotional text, description, keywords, support URL, privacy URL, copyright, optional blank marketing URL.
- App Review information: contact, reviewer login email, real reviewer password, review notes.
- Build: processed `1.0.31` build from the current `v1.0.31` tag.
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
- `flutter build ios --release --no-codesign`
- `bash tool/ci/run_web_e2e.sh`
- Fastlane syntax check
- App Store metadata workflow YAML parse
- Build iOS workflow YAML parse
- Fastlane screenshot validation for five screenshots
- Live legal URLs returned `200` for `/privacy`, `/terms`, and `/support`

Re-run the relevant checks after changing code, metadata automation, screenshots, entitlements, Firebase rules, or release workflows.
