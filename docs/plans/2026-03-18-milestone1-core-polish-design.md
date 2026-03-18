# Milestone 1: Core Polish — Design

**Date:** 2026-03-18

## 1. Remove demo seed data + Onboarding

- New users see a 2-step onboarding screen on first launch (before dashboard)
- Step 1: Name input with welcoming headline
- Step 2: Unit preference toggle (kg/lbs)
- On submit: save name + unit to Firestore state, start with empty AppState
- Returning users skip onboarding (userName already set)
- Add `userName` and `preferredUnit` fields to AppState model
- Dashboard profile header shows actual name instead of hardcoded "Alex"

## 2. Unit preference (kg/lbs)

- Stored in `AppState.preferredUnit` ('kg' or 'lbs')
- All weight displays use `AppFormatters.weight(kg, unit)` for conversion
- Data always stored in kg internally — conversion only at display/input layer
- Conversion: 1 kg = 2.20462 lbs
- Weight input fields show current unit label
- Changeable later via account bottom sheet settings

## 3. Rest timer audio

- Bundle triple-beep audio asset (~1s MP3)
- Play via audioplayers package when rest timer hits zero
- Only plays once per rest period
- Works on iOS and web/Safari

## 4. Offline indicator

- connectivity_plus package to listen for changes
- Snackbar "You're offline — changes saved locally" on disconnect
- Snackbar "Back online" on reconnect
- Auto-dismiss after 3 seconds

## 5. Error handling UI

- Global error handler shows snackbar for Firestore write failures
- Auth expiry: re-authenticate silently, snackbar only if re-auth fails

## 6. Exercise reordering

- ReorderableListView in routine editor
- Drag handle icon on exercise cards
- Update order field on reorder

## 7. App icon & splash screen

- Primary blue (#257BF4) background, white dumbbell icon
- flutter_launcher_icons for all platform icon sizes
- flutter_native_splash for splash screen

## AppState model changes

```
AppState:
  + userName: String (default '')
  + preferredUnit: String (default 'kg')
```

## Files affected

- `lib/src/data/models/app_state.dart` — add userName, preferredUnit
- `lib/src/data/seed/demo_seed_data.dart` — remove or make conditional
- `lib/src/core/utils/formatters.dart` — add weight formatter with unit conversion
- `lib/main.dart` — onboarding check before dashboard
- `lib/src/app/router.dart` — add onboarding route
- New: `lib/src/features/onboarding/onboarding_screen.dart`
- `lib/src/features/dashboard/dashboard_screen.dart` — use real name
- `lib/src/features/workout/active_workout_screen.dart` — unit-aware weight display/input
- `lib/src/features/workout/workout_summary_screen.dart` — unit-aware displays
- `lib/src/features/progress/progress_screen.dart` — unit-aware displays
- `lib/src/features/auth/account_section.dart` — add unit preference toggle
- `lib/src/features/routines/routine_editor_screen.dart` — ReorderableListView
- `lib/src/shared/widgets/common_widgets.dart` — offline snackbar helper
- `pubspec.yaml` — add audioplayers, connectivity_plus, flutter_launcher_icons, flutter_native_splash
- New: `assets/audio/rest_timer_beep.mp3`
