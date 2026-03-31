# Rebrand: Kotrana: Musculation

**Date:** 2026-03-31
**Scope:** Display name + companion features (Option C)

## Naming Map

| Component | Old | New |
|-----------|-----|-----|
| App display name (EN + FR) | Strength Training Tracker / Suivi de Musculation | Kotrana: Musculation |
| Web short name | Strength Tracker | Kotrana |
| iOS home screen | Strength Training Tracker | Kotrana: Musculation |
| Watch app | StrengthAppWatch | Kotrana Watch |
| Live Activity | Strength Live | Kotrana Live |
| Watch prompt (EN) | Open StrengthApp on your iPhone | Open Kotrana on your iPhone |
| Watch prompt (FR) | Ouvrez StrengthApp sur votre iPhone | Ouvrez Kotrana sur votre iPhone |
| SideStore listing | Strength Training Tracker | Kotrana: Musculation |
| Web meta description | References old name | Updated to Kotrana |

## Unchanged

- Dart package name: `strength_training_tracker`
- Internal class names: `StrengthTrainingApp`, etc.
- Bundle identifiers: `dev.mamy-r.kotrana`
- IPA filenames and GitHub workflow artifact names
- App icon

## Files to update

1. `pubspec.yaml` -- description
2. `lib/l10n/app_en.arb` + `app_fr.arb` -- appTitle
3. `lib/src/app/app.dart` -- MaterialApp title
4. `ios/Runner/Info.plist` -- CFBundleDisplayName, CFBundleName
5. `ios/StrengthAppLiveActivity-Info.plist` -- CFBundleDisplayName
6. `ios/Runner.xcodeproj/project.pbxproj` -- Watch display name (3x)
7. `ios/StrengthAppWatch Watch App/ContentView.swift` -- Text display
8. `ios/StrengthAppWatch Watch App/WatchLocalizations.swift` -- EN/FR strings
9. `web/index.html` -- title, meta tags
10. `web/manifest.json` -- name, short_name
11. `sidestore-source.json` -- name fields
