# Kotrana App Store Public Release Plan

Date: 2026-05-16
Target candidate: `v1.0.31`
Build number: `286`
Release mode: manual release after App Review approval

This plan captures the decisions needed to prepare Kotrana: Musculation for its first public App Store release. It is intended to survive context loss and let a future Codex session continue without re-interviewing the user.

## Current Known State

- `main` contains the merged release-prep work and `v1.0.31` currently points at `c5fb55b`.
- TestFlight/App Store Connect has uploaded build `1.0.30 (272)`.
- The release-prep work now bumps `pubspec.yaml` to `1.0.31+286`; after retagging `v1.0.31` to the current release-prep commit, the workflow should upload App Store Connect build `1.0.31 (286)`.
- The public App Store version page was still using old build `1.0.23 (238)` and must be updated after the final release-prep build.
- App Store Connect status was `1.0 Prepare for Submission`.
- App Store metadata, screenshots, App Privacy, pricing/availability, age rating, regulated medical device declaration, and accessibility labels were not yet complete.
- App Store text metadata and App Review contact notes are now stored under `ios/fastlane/metadata`.
- App Store screenshots are now prepared under `ios/fastlane/screenshots/en-US` as `1290 x 2796` iPhone 6.9-inch portrait PNGs.
- Manual workflow `.github/workflows/app-store-metadata.yml` can sync the stored metadata to the App Store version `1.0` page after adding the `APP_REVIEW_DEMO_PASSWORD` GitHub secret. It can also upload the prepared screenshots when `upload_screenshots` is enabled.
- Existing untracked files at time of planning were GPT Pro artifacts in `docs/`; leave them untouched unless specifically needed.

## Current Blocker

- Build iOS workflow `25964141727` fails before archive because Apple Developer rejects enabling `APPLE_ID_AUTH` for `dev.mamy-r.kotrana` through the App Store Connect API key.
- Error observed on rerun job `76324827607`: `This request is forbidden for security reasons - You are not allowed to perform this operation.`
- Manual Team Admin action required before rerunning the tag workflow:
  1. Apple Developer > Certificates, Identifiers & Profiles.
  2. Open identifier `dev.mamy-r.kotrana`.
  3. Enable `Sign in with Apple`.
  4. Save the identifier.
- After this, rerun the `v1.0.31` Build iOS workflow. The Fastlane lane should detect the existing capability, regenerate the App Store profile with `match(force: true)`, and continue to archive/upload.

## Metadata Automation Status

- GitHub secret `APP_REVIEW_DEMO_PASSWORD` is set.
- Manual workflow `Sync App Store Metadata` targets the existing App Store version page `1.0`.
- Workflow run `25964706927` verified that Fastlane can authenticate, find App Store version `1.0`, and load every metadata/review-info file from `ios/fastlane/metadata`.
- The same run failed when uploading metadata with: `This request is forbidden for security reasons - The API key in use does not allow this request`.
- To use metadata automation, replace/update the App Store Connect API key GitHub secrets with a key that has permission to edit App Store metadata, such as an App Manager/Admin-capable key, or fill the fields manually in App Store Connect from `docs/app-store-connect-submission-values.md`.

## Product and Access Decisions

- Public App Store distribution: yes, discoverable, free, available everywhere.
- In-app access: invite-only.
- Anonymous Firebase auth: remove entirely for release.
- Demo button: keep only for debug/dev builds; hide in release/TestFlight/App Store builds.
- Login methods, in this order:
  1. Email/password
  2. Continue with Apple
  3. Continue with Google
- Google sign-in stays because existing invited users use it.
- Sign in with Apple must be added visibly and configured with the iOS entitlement because Google sign-in remains visible.
- No open self-signup.
- Email verification: not required for v1.0 because invite-only allowlist controls access and the App Review account uses a non-monitored address.

## Reviewer Account

- Reviewer email: `app-review@mamy-r.dev`
- Reviewer password: `<review-password>`
- User said this Firebase user is already created and authorized for sign-in.
- Seed this account with rich demo data equivalent to `DemoSeedData.initialState()` using `tool/seed_review_account.dart`.
- App Review notes should say the account includes demo workout, routine, and history data.

## Invite Allowlist

Use a Firestore allowlist by email.

Collection: `allowedEmails`

Document ID: normalized lowercase email.

Fields:

```json
{
  "email": "<email>",
  "enabled": true,
  "role": "reviewer|user|admin",
  "createdAt": "<server timestamp>"
}
```

Launch entries:

- `app-review@mamy-r.dev`, role `reviewer`
- `ramiasamananaando5@gmail.com`, role `user`
- `nyandrianinamamy@gmail.com`, role `admin`

Seed/update these entries with:

```bash
KOTRANA_FIREBASE_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
dart run tool/seed_release_access.dart
```

Unauthorized signed-in behavior:

- Show a blocking screen with this text:
  `Access to Kotrana is currently invite-only. If you've been invited, sign in with the method linked to your account.`
- Include a `Sign out` button.
- Do not create Firestore app data.
- Do not allow dashboard access.

Admin role:

- `nyandrianinamamy@gmail.com` should be `admin`.
- No in-app allowlist management for v1.0.
- Admin/debug UI may be hidden by debug/feature flag for this account, but should not be public release surface.

## Firebase and Security Rules

Implementation must enforce invite-only access server-side, not only in UI.

Rules intent:

- User app data read/write only if signed in and `allowedEmails/{normalizedEmail}` exists with `enabled == true`.
- Client must not write to `allowedEmails`.
- Allowlist reads should be limited to the matching signed-in email or otherwise minimized.
- Ensure unauthorized Google/Apple/email sign-ins cannot create app state documents.

Open implementation detail: Firestore rules string normalization support is limited; verify whether lowercasing can be done in rules. If not, store/check canonical email carefully or use UID-based allowlist with email as metadata. The product decision remains "allowlist by email".

## Account Deletion

- Delete account must remove both Firebase Auth user and Firestore app data.
- Allowlist entry may remain so the user can be re-created/reinvited later.
- Verify account deletion works for email/password and social accounts.
- App Privacy and App Review notes should mention in-app deletion through Settings.

## HealthKit and Permissions

Keep:

- Normal HealthKit entitlement.
- HealthKit usage strings for optional Apple Health integration.
- Camera and photo library usage strings as-is.

Remove unless code proves needed:

- `com.apple.developer.healthkit.access = health-records` from Runner and Watch entitlements. This is Clinical Health Records, not ordinary HealthKit data.
- `com.apple.developer.healthkit.background-delivery = true` unless implementation proves background HealthKit delivery is required.
- `NSBluetoothAlwaysUsageDescription` unless direct Bluetooth/BLE fitness accessory code exists. Apple Watch communication does not require this usage string.

Privacy and review wording for HealthKit:

`Apple Health access is optional. The reviewer account includes demo workout/routine/history data. Readiness features can also incorporate sleep, HRV, and resting heart rate if Apple Health permission is granted on the review device.`

HealthKit data is not used for advertising, marketing, tracking, or data mining.

## Legal and Public URLs

Domain is already attached to Firebase Hosting:

- `https://kotrana.mamy-r.dev`

Use extensionless URLs:

- Privacy Policy: `https://kotrana.mamy-r.dev/privacy`
- Terms of Use: `https://kotrana.mamy-r.dev/terms`
- Support URL: `https://kotrana.mamy-r.dev/support`

Marketing URL:

- Leave blank if App Store Connect allows it.
- Do not use the root as a marketing page because root is the web version of the app.

Support page minimal content:

- Title: `Kotrana Support`
- Body: `Need help with Kotrana: Musculation, account access, account deletion, or privacy questions? Contact the developer by email.`
- Contact: `nyandrianinamamy@gmail.com`
- Links to Privacy Policy and Terms.

Code task:

- Update default legal base URL from `https://myappv4.web.app` to `https://kotrana.mamy-r.dev`.
- Configure Firebase Hosting rewrites/redirects so `/privacy`, `/terms`, and `/support` work.
- Verify all URLs return `200` over HTTPS.

## App Store Metadata

App name:

- `Kotrana: Musculation`

Subtitle:

- `Strength training tracker`

Promotional text:

- `Plan routines, log workouts, and track progress with a scientific training engine and Apple Watch support.`

Description:

```text
Kotrana: Musculation is an invite-only strength training tracker for lifters who want structured routines, focused workout logging, and clearer progress feedback.

Build and follow routines, log sets with weight and reps, review workout history, and track progress over time. Kotrana includes a scientific training engine that helps organize training load, readiness, fatigue, and progression signals so your plan can stay practical from session to session.

Apple Watch support lets you follow active workout state from your wrist, while Live Activities keep the current session visible on iPhone. Optional Apple Health integration can use sleep, heart rate variability, and resting heart rate to improve readiness context when you grant permission.

Kotrana is designed to be private and focused: access is invite-only, account sync is available for approved users, and Apple Health data is not used for advertising, marketing, or data mining.
```

Keywords:

- `strength,workout,gym,fitness,training,tracker,weights,routines,progress`

Copyright:

- `© 2026 Mamy Razafintsialonina`

Support URL:

- `https://kotrana.mamy-r.dev/support`

Privacy Policy URL:

- `https://kotrana.mamy-r.dev/privacy`

Marketing URL:

- Blank if allowed.

Category:

- Primary: `Health & Fitness`
- Secondary: `Sports`

Content rights:

- No third-party content requiring rights.

Encryption/export compliance:

- Keep `ITSAppUsesNonExemptEncryption = false`.
- App uses standard platform encryption/HTTPS only; no non-exempt proprietary encryption.

## Pricing and Availability

- Price: Free.
- Availability: all countries/regions.
- Distribution: public/discoverable.
- In-app access remains invite-only.
- Apple Silicon Mac availability: no for v1.0.
- Apple Vision Pro availability: no for v1.0.
- Release mode: manual release after App Review approval.

## Age Rating

Planned answers:

- No unrestricted web access.
- No user-generated public content.
- No messaging/chat.
- No advertising.
- No gambling, contests, loot boxes, or simulated gambling.
- No violence, sexual content, drugs, alcohol, horror, profanity, or crude humor.
- Health or wellness topics: yes.
- Medical or treatment information: no, or "none/infrequent" depending on exact App Store wording.
- Parental controls / age assurance: no.

Expected outcome: low age rating with Health & Fitness context.

## Regulated Medical Device

- Declare: not a regulated medical device.
- Rationale: Kotrana tracks workouts and provides fitness/readiness context. It does not diagnose, treat, monitor a disease, or replace medical advice.
- Keep this wording aligned in metadata, privacy policy, terms, and review notes.

## App Privacy

Data linked to user:

- Contact Info: email address.
- Identifiers: Firebase user ID/account identifier.
- Health & Fitness: workouts, routines, progress, readiness/training data, optional HealthKit-derived sleep, HRV, and resting heart rate.
- User Content: optional machine/exercise photos, especially if synced as `photoBase64`.

Not collected:

- Crash/diagnostic data beyond Apple's normal platform reporting.
- Tracking data.
- Advertising data.

Use:

- App functionality only.
- Not tracking.
- Not third-party advertising.

Machine photos:

- Disclose as collected/linked to user when sync is enabled.
- Used only for app functionality.

HealthKit:

- Disclose as optional and linked to user if permission granted and synced.
- Used only for app functionality: readiness, recovery context, workout tracking/history.
- Not used for advertising, marketing, tracking, or data mining.

## Accessibility Labels

Do not claim accessibility support blindly.

Verify before filling:

- Dark Interface.
- Larger Text / Dynamic Type.
- Sufficient Contrast.
- Differentiate Without Color Alone.
- VoiceOver sanity check if practical.

Do not claim unless truly verified:

- VoiceOver.
- Voice Control.
- Reduced Motion.
- Captions.
- Audio Descriptions.

## Screenshots

Prepare all screenshot sets that apply:

- iPhone screenshots.
- iPad screenshots if iPad support is listed.
- Apple Watch screenshots because the app includes a Watch companion.

Use demo/reviewer account data or equivalent rich demo state.

Suggested screenshot coverage:

1. Dashboard/readiness/progress overview.
2. Active workout logging.
3. Workout summary/history.
4. Routine planning or smart planner.
5. Apple Watch companion and/or Live Activity.

Use real app screenshots, not generic mockups.

App Store localization:

- English (U.S.) only for first submission.
- French in-app UI can remain; French App Store localization can come later.

## App Review Information

Contact:

- First name: `Mamy`
- Last name: `Razafintsialonina`
- Email: `nyandrianinamamy@gmail.com`
- Phone: `+33755639903`

Reviewer sign-in:

- Sign-in required: yes.
- Email: `app-review@mamy-r.dev`
- Password: `<review-password>`

Review notes:

```text
Kotrana is invite-only. Please use the reviewer account below to access all app features.

Email: app-review@mamy-r.dev
Password: <review-password>

The reviewer account includes demo workout, routine, and history data.

Suggested review flow:
1. Open the dashboard to view progress, readiness, and muscle heatmap summaries.
2. Start a workout from an existing routine and log sets, reps, weight, and RPE.
3. Finish the workout and view the workout summary/history.
4. Open routines/planning to review routine structure and training recommendations.
5. Open Settings to review account sync, account deletion, legal links, and optional Apple Health access.
6. If reviewing with an Apple Watch paired, start a workout on iPhone and view active workout state on the Watch.
7. During an active workout, view the iPhone Live Activity if available.

Apple Health access is optional. The reviewer account includes demo workout/routine/history data. Readiness features can also incorporate sleep, HRV, and resting heart rate if Apple Health permission is granted on the review device.

Kotrana is free and has no in-app purchases or subscriptions.
```

## Code Implementation Tasks

1. Add email/password login UI and service path.
2. Add visible Sign in with Apple UI next to Google and configure iOS entitlement/capability.
3. Keep Google sign-in working for existing invited users.
4. Remove release anonymous auth bootstrap.
5. Hide `Explore with Demo Data` outside debug/dev builds.
6. Add invite-only allowlist check after sign-in and before app data loading/creation.
7. Add unauthorized access blocking screen and sign-out flow.
8. Update settings sign-in/account switching to support email/password, Apple, and Google correctly.
9. Verify delete account removes Auth user and Firestore app data.
10. Add/adjust Firestore Security Rules for allowlisted access only.
11. Add one-off seed path/script for reviewer account using `DemoSeedData.initialState()`.
12. Remove Clinical Health Records entitlement.
13. Remove HealthKit background delivery unless proven needed.
14. Remove Bluetooth usage string unless direct Bluetooth code is found.
15. Add extensionless legal/support routes and support page.
16. Update legal URL defaults to `https://kotrana.mamy-r.dev`.
17. Update privacy/terms wording if needed to match invite-only, email/password, Apple/Google, HealthKit, machine photos, no diagnostics.
18. Add/update tests for auth gating, demo button visibility, allowlist behavior, account deletion, legal links, and entitlement/Info.plist expectations.

## Verification Tasks

Before tagging `v1.0.31`:

- `flutter analyze --no-fatal-infos`
- `flutter test`
- `cd packages/training_engine && dart test`
- `bash tool/ci/run_web_e2e.sh`
- Verify Firebase Hosting URLs:
  - `https://kotrana.mamy-r.dev/privacy`
  - `https://kotrana.mamy-r.dev/terms`
  - `https://kotrana.mamy-r.dev/support`
- Verify Firestore rules with allowed and unauthorized users.
  - Local emulator command:
    `firebase emulators:exec --only auth,firestore --project myappv4 "dart run tool/verify_firestore_rules.dart"`
- Verify reviewer account loads seeded demo data.
- Verify unauthorized user sees invite-only blocking screen and cannot create app data.
- Verify email/password login.
- Verify Google login for existing allowlisted users.
- Verify Apple login on iOS after entitlement/configuration.
- Verify account deletion for email/password and social accounts.
- Verify no anonymous auth path in release.
- Verify demo data button is present only in debug/dev builds.
- Verify HealthKit permission prompts and optional behavior.
- Verify camera/photo permissions for machine photos.
- Verify Apple Watch companion active workout state.
- Verify Live Activity during active workout.
- Verify App Store screenshots from latest build.
- Verify accessibility claims before filling App Store Connect.

## Release and Submission Tasks

1. Create release-prep branch.
2. Implement code and metadata/support-site changes.
3. Commit and open PR.
4. Wait for PR checks and merge.
5. Tag merged `main` as `v1.0.31`.
6. Confirm GitHub Actions iOS/TestFlight upload succeeds.
7. Confirm App Store Connect receives build `1.0.31 (286)`.
8. Select latest build for iOS App Version `1.0`.
9. Sync App Store text metadata and App Review information with the manual `Sync App Store Metadata` workflow, or fill manually from `docs/app-store-connect-submission-values.md`.
10. Fill App Privacy, pricing/availability, age rating, regulated medical device declaration, accessibility labels, and any screenshots not covered by Fastlane metadata.
11. Upload screenshots.
12. Choose manual release.
13. Add for Review and submit.

## Open Checks Before Implementation

- Confirm Firebase Auth email/password provider is enabled.
- Confirm Firebase Auth Apple provider is configured.
- Confirm Apple developer capability for Sign in with Apple is enabled for `dev.mamy-r.kotrana`.
- Confirm App Store Connect API key can edit app metadata, or plan to fill App Store Connect manually.
- Confirm Firestore data document path used by `FirestoreAppStateRepository`.
- Confirm whether HealthKit background delivery is referenced anywhere beyond entitlements.
- Confirm whether direct Bluetooth/BLE code exists; remove Bluetooth string if not.
- Confirm screenshot device requirements shown by App Store Connect after selecting the final build.

## Reviewer Account Seeding Command

After the allowlist contains `app-review@mamy-r.dev`, run:

```bash
KOTRANA_REVIEW_EMAIL='app-review@mamy-r.dev' \
KOTRANA_REVIEW_PASSWORD='<review-password>' \
dart run tool/seed_review_account.dart
```

Do not commit the real password into source files or shell history snippets.
