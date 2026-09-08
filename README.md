# Kotrana: Musculation

Offline-first strength training for iPhone and Apple Watch. The Flutter app owns workouts, routines, exercises, progress and account state. The native Watch companion and Live Activity extension live under `ios/`.

The app keeps private email invitations, Firebase sync, local storage, HealthKit, French/English localization and responsive layouts. There is no Flutter web application. `site/` contains the standalone legal and support pages used by the app.

## Development

Release toolchain: Flutter 3.41.9 and Xcode 26.3. Use `ios/Runner.xcworkspace`, scheme `Runner`, for native builds.

```bash
flutter pub get
flutter run -d <ios-simulator-udid>
```

Lexend fonts and their license are bundled for fresh offline installs.

## Verification

```bash
flutter analyze --no-fatal-infos
flutter test
(cd packages/training_engine && dart pub get && dart test)
(cd packages/flutter_body_heatmap && flutter pub get && flutter test)
bash tool/ci/run_native_regressions.sh
python3 tool/ci/verify_static_site.py
bash tool/ci/run_ios_e2e.sh --with-auth --paired-watch
```

Native E2E requires macOS, Xcode, installed iOS/watchOS runtimes, Firebase CLI 15.10.1, Java 21 and AXe 1.8.0 (`AXE_PATH`; bundled with `xcodebuildmcp@2.7.0`). It uses a disposable simulator pair and a demo Firebase project. Read [test coverage and setup](docs/ios-e2e-coverage.md) before running; do not use simulators holding real accounts or workouts.

PR checks and TestFlight builds verify the same source commit with the pinned toolchain. TestFlight upload waits for the checks. Physical-device acceptance is still required for real HealthKit, Watch delivery, notification and Live Activity behavior.

See the [approved plan](docs/plans/2026-09-08-ios-watch-cleanup-review.md) and [implementation record](docs/reviews/2026-09-08-implementation-record.md) for changes and evidence. Historical design and review documents remain under `docs/`; they do not define current supported platforms.
