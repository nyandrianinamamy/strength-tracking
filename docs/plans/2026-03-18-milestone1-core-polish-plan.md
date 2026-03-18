# Milestone 1: Core Polish — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Polish the app for real-world use: onboarding, kg/lbs units, rest timer audio, offline indicator, error handling, exercise reordering, app icon.

**Architecture:** Add `userName` and `preferredUnit` to AppState, gate dashboard behind onboarding check, add unit-aware formatting throughout. Audio via audioplayers, connectivity via connectivity_plus. ReorderableListView for exercise drag-drop.

**Tech Stack:** audioplayers, connectivity_plus, flutter_launcher_icons, flutter_native_splash

---

### Task 1: Add userName and preferredUnit to AppState

**Files:**
- Modify: `lib/src/data/models/app_state.dart`

**Step 1: Update AppState model**

Add `userName` (String, default `''`) and `preferredUnit` (String, default `'kg'`) to:
- Constructor (with defaults)
- `copyWith`
- `fromJson` / `toJson`
- `empty()` factory

**Step 2: Update `main.dart`**

Replace the demo seed data block. Instead of seeding `DemoSeedData.initialState()` when Firestore is empty, just leave the empty state — onboarding (Task 3) will handle new users.

Remove lines 58-62 in main.dart:
```dart
    // If Firestore returned empty, seed with demo data
    if (initialState.exercises.isEmpty && initialState.routines.isEmpty) {
      initialState = DemoSeedData.initialState();
      await repository.save(initialState);
    }
```

**Step 3: Verify**

Run: `flutter analyze && flutter test`
Expected: analyze clean, some tests may need AppState constructor updates

**Step 4: Commit**

```bash
git commit -m "feat: add userName and preferredUnit to AppState, remove auto-seeding"
```

---

### Task 2: Add weight formatter with unit conversion

**Files:**
- Modify: `lib/src/core/utils/formatters.dart`

**Step 1: Add weight formatter**

Add to `AppFormatters`:
```dart
static const double _kgToLbs = 2.20462;

static double convertWeight(double kg, String unit) {
  if (unit == 'lbs') return kg * _kgToLbs;
  return kg;
}

static double convertToKg(double value, String unit) {
  if (unit == 'lbs') return value / _kgToLbs;
  return value;
}

static String weight(double kg, String unit) {
  final converted = convertWeight(kg, unit);
  return '${decimal(converted)} $unit';
}
```

**Step 2: Verify**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git commit -m "feat: add unit-aware weight formatter with kg/lbs conversion"
```

---

### Task 3: Create onboarding screen

**Files:**
- Create: `lib/src/features/onboarding/onboarding_screen.dart`
- Modify: `lib/src/app/router.dart`

**Step 1: Create onboarding screen**

A simple `StatefulWidget` with a PageView (2 pages):

Page 1: Welcome headline ("Let's get started"), name TextField, "Next" button.

Page 2: Unit preference — two large tappable cards (KG highlighted blue / LBS outlined, or vice versa), "Start Training" button.

On submit: call `ref.read(appStateControllerProvider.notifier).updateState()` to set `userName` and `preferredUnit`, then navigate to `/`.

**Step 2: Add onboarding route**

In `router.dart`, add a route:
```dart
GoRoute(
  path: '/onboarding',
  builder: (context, state) => const OnboardingScreen(),
),
```

**Step 3: Add redirect logic in router**

Add `redirect` to the GoRouter that checks if `userName` is empty — if so, redirect to `/onboarding` (except if already on `/onboarding`). This requires accessing the AppState, so pass it via a provider or use a `refreshListenable`.

Simpler approach: in `main.dart`, check `initialState.userName.isEmpty` and set `initialLocation: '/onboarding'` on the GoRouter.

**Step 4: Verify**

Run: `flutter analyze`

**Step 5: Commit**

```bash
git commit -m "feat: add onboarding screen with name and unit preference"
```

---

### Task 4: Update dashboard to use real name

**Files:**
- Modify: `lib/src/features/dashboard/dashboard_screen.dart`

**Step 1: Replace hardcoded "Alex"**

Change the profile header to read from state:
```dart
final userName = state.userName.isEmpty ? 'Athlete' : state.userName;
```
Use `userName` instead of the hardcoded `'Alex'`.

**Step 2: Commit**

```bash
git commit -m "feat: show user's actual name on dashboard"
```

---

### Task 5: Apply unit-aware formatting across all screens

**Files:**
- Modify: `lib/src/features/dashboard/dashboard_screen.dart`
- Modify: `lib/src/features/workout/active_workout_screen.dart`
- Modify: `lib/src/features/workout/workout_summary_screen.dart`
- Modify: `lib/src/features/progress/progress_screen.dart`

**Step 1: Update all weight displays**

Every place that shows `${AppFormatters.decimal(X)} kg` should become `AppFormatters.weight(X, state.preferredUnit)`.

For weight input labels, change `'WEIGHT (KG)'` to `'WEIGHT (${state.preferredUnit.toUpperCase()})'.

For weight input parsing (active workout LOG button), convert input to kg before storing:
```dart
final rawWeight = double.tryParse(weightController.text.replaceAll(',', '.'));
final weight = rawWeight == null ? null : AppFormatters.convertToKg(rawWeight, state.preferredUnit);
```

State must be accessible in the _ExercisePage widget — pass `preferredUnit` as a parameter.

**Step 2: Verify**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git commit -m "feat: apply unit-aware weight formatting across all screens"
```

---

### Task 6: Add unit toggle to account section

**Files:**
- Modify: `lib/src/features/auth/account_section.dart`

**Step 1: Add unit preference toggle**

Below the auth status section, add a segment showing current unit with toggle:
```dart
// After the auth buttons/status text, add:
const SizedBox(height: 24),
const Divider(),
const SizedBox(height: 16),
Text('Unit Preference', style: bold),
const SizedBox(height: 12),
SegmentedButton<String>(
  segments: [
    ButtonSegment(value: 'kg', label: Text('KG')),
    ButtonSegment(value: 'lbs', label: Text('LBS')),
  ],
  selected: {currentUnit},
  onSelectionChanged: (values) {
    ref.read(appStateControllerProvider.notifier).updateState(
      (s) => s.copyWith(preferredUnit: values.first),
    );
    Navigator.pop(context);
  },
),
```

This requires making AccountSection a ConsumerWidget that reads appStateControllerProvider.

**Step 2: Commit**

```bash
git commit -m "feat: add unit preference toggle to account section"
```

---

### Task 7: Add rest timer audio

**Files:**
- Modify: `pubspec.yaml` — add `audioplayers: ^6.1.0` and asset declaration
- Create: `assets/audio/` directory
- Create or download: `assets/audio/rest_timer_beep.mp3`
- Modify: `lib/src/features/workout/active_workout_screen.dart`

**Step 1: Add audioplayers dependency and asset**

In `pubspec.yaml`:
```yaml
dependencies:
  audioplayers: ^6.1.0
```

Under `flutter:`:
```yaml
  assets:
    - assets/audio/
```

Generate a triple-beep MP3 programmatically or use a royalty-free beep sound. If no audio file is available, use `AudioPlayer` with a `UrlSource` pointing to a public beep URL, or generate tones using `AudioPlayer`'s tone generation.

Simplest approach: use the `Tone` generator from audioplayers or play a system sound. Actually, the simplest cross-platform approach is to use `AudioCache` with a bundled asset.

**Step 2: Add audio playback to active workout**

In `_ActiveWorkoutScreenState`, add:
```dart
final _audioPlayer = AudioPlayer();
bool _restTimerBeeped = false;
```

In the `_resetRestTimer` method, reset `_restTimerBeeped = false`.

In the build's ticker (or computed `_remainingRest`), when rest hits 0 and `!_restTimerBeeped`:
```dart
if (_remainingRest == 0 && _restTimerStart != null && !_restTimerBeeped) {
  _restTimerBeeped = true;
  _audioPlayer.play(AssetSource('audio/rest_timer_beep.mp3'));
}
```

Dispose the audio player in `dispose()`.

**Step 3: Commit**

```bash
git commit -m "feat: play triple-beep audio when rest timer reaches zero"
```

---

### Task 8: Add offline indicator

**Files:**
- Modify: `pubspec.yaml` — add `connectivity_plus: ^6.1.2`
- Modify: `lib/src/app/app.dart` — add connectivity listener

**Step 1: Add connectivity_plus**

In `pubspec.yaml`:
```yaml
  connectivity_plus: ^6.1.2
```

**Step 2: Add connectivity listener in app.dart**

Wrap the MaterialApp.router in a `ConnectivityListener` widget (or add logic in the app widget) that listens to `Connectivity().onConnectivityChanged` and shows snackbars:

```dart
// In a StatefulWidget wrapper or in StrengthTrainingApp:
Connectivity().onConnectivityChanged.listen((result) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  if (result.contains(ConnectivityResult.none)) {
    messenger.showSnackBar(SnackBar(
      content: Text('You\'re offline — changes saved locally'),
      duration: Duration(seconds: 3),
    ));
  } else {
    messenger.showSnackBar(SnackBar(
      content: Text('Back online'),
      duration: Duration(seconds: 2),
    ));
  }
});
```

Add a `GlobalKey<ScaffoldMessengerState>` to the MaterialApp.router:
```dart
scaffoldMessengerKey: _messengerKey,
```

**Step 3: Commit**

```bash
git commit -m "feat: show offline/online snackbar notifications"
```

---

### Task 9: Add error handling UI

**Files:**
- Modify: `lib/src/core/app_state_controller.dart`

**Step 1: Add error handling to save operations**

The `AppStateController.replaceState` calls `repository.save()` without error handling. Wrap it:

```dart
void replaceState(AppState nextState) {
  state = nextState;
  unawaited(
    ref.read(appStateRepositoryProvider).save(nextState).catchError((e) {
      debugPrint('Failed to save state: $e');
      // Could expose an error stream here for UI to listen to
    }),
  );
}
```

For now, Firestore's offline cache handles most failures gracefully — writes are queued and synced when online. The offline indicator (Task 8) already tells the user they're offline. More sophisticated error handling can be added later if needed.

**Step 2: Commit**

```bash
git commit -m "feat: add error handling to state persistence"
```

---

### Task 10: Add exercise reordering in routine editor

**Files:**
- Modify: `lib/src/features/routines/routine_editor_screen.dart`

**Step 1: Replace exercise list with ReorderableListView**

Wrap the exercise cards section in a `ReorderableListView.builder` (or `ReorderableListView`):

```dart
ReorderableListView(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
      _reindexExercises();
    });
  },
  children: [
    for (final entry in _exercises.asMap().entries)
      _buildExerciseCard(entry.key, entry.value, state, context),
  ],
)
```

Add a drag handle (`Icons.drag_handle`) to each exercise card, aligned to the right or left of the card header row. Use `key: ValueKey(entry.key)` on each card.

**Step 2: Commit**

```bash
git commit -m "feat: add drag-to-reorder exercises in routine editor"
```

---

### Task 11: App icon and splash screen

**Files:**
- Modify: `pubspec.yaml` — add dev dependencies and config
- Create: `assets/icon/` directory
- Create: app icon source image (1024x1024 PNG)

**Step 1: Add dependencies**

In `pubspec.yaml` under `dev_dependencies:`:
```yaml
  flutter_launcher_icons: ^0.14.3
```

Add config at the root level of pubspec.yaml:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  web:
    generate: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#257BF4"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

For `flutter_native_splash`, add under `dev_dependencies:`:
```yaml
  flutter_native_splash: ^2.4.4
```

Add config:
```yaml
flutter_native_splash:
  color: "#257BF4"
  image: "assets/icon/app_icon_foreground.png"
  android: true
  ios: true
  web: true
```

**Step 2: Create icon assets**

Create a simple 1024x1024 icon: blue (#257BF4) background with a white dumbbell shape. This can be a simple vector-to-PNG export. If no design tool is available, create a minimal icon using Flutter's canvas and export it, or use a placeholder.

**Step 3: Generate icons and splash**

Run:
```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

**Step 4: Commit**

```bash
git commit -m "feat: add branded app icon and splash screen"
```

---

### Task 12: Final verification and deploy

**Step 1: Run analyze and tests**

```bash
flutter analyze
flutter test
```

**Step 2: Build and deploy**

```bash
flutter build web --release
firebase deploy --only hosting
```

**Step 3: Verify onboarding flow on deployed site**

Open in private browser window — should see onboarding, not dashboard.

**Step 4: Commit any remaining changes**

```bash
git commit -m "chore: milestone 1 complete — core polish"
```
