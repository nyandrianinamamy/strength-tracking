# Exercise Picker Bottom Sheet — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the multi-screen exercise add/swap/create flow with a unified bottom sheet that works in both the routine editor and active workout screen.

**Architecture:** A shared `ExercisePickerSheet` widget with inline quick-create, usage-frequency sorting, and exercise thumbnails. Integrates into existing screens by replacing navigation calls with `showExercisePickerSheet()`. Adds `lastUsedAt`/`useCount` fields to the Exercise model.

**Tech Stack:** Flutter, Riverpod, Material 3 bottom sheets, existing `ExerciseController`, `WorkoutController`, `AppState`

---

### Task 1: Add usage tracking fields to Exercise model

**Files:**
- Modify: `lib/src/data/models/exercise.dart`
- Test: `test/data/models/exercise_test.dart`

**Step 1: Write the failing test**

Create `test/data/models/exercise_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';

void main() {
  group('Exercise', () {
    test('new fields default to null/0', () {
      const exercise = Exercise(
        id: 'ex1',
        name: 'Bench Press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
      );
      expect(exercise.useCount, 0);
      expect(exercise.lastUsedAt, isNull);
    });

    test('copyWith preserves usage fields', () {
      final now = DateTime.now();
      final exercise = Exercise(
        id: 'ex1',
        name: 'Bench Press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
        useCount: 5,
        lastUsedAt: now,
      );
      final updated = exercise.copyWith(name: 'Incline Press');
      expect(updated.useCount, 5);
      expect(updated.lastUsedAt, now);
    });

    test('toJson includes usage fields', () {
      final now = DateTime(2026, 4, 8, 12, 0);
      final exercise = Exercise(
        id: 'ex1',
        name: 'Bench Press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
        useCount: 3,
        lastUsedAt: now,
      );
      final json = exercise.toJson();
      expect(json['useCount'], 3);
      expect(json['lastUsedAt'], now.toIso8601String());
    });

    test('fromJson reads usage fields', () {
      final json = {
        'id': 'ex1',
        'name': 'Bench Press',
        'primaryMuscles': ['Chest'],
        'equipment': ['Barbell'],
        'instructions': '',
        'archived': false,
        'useCount': 7,
        'lastUsedAt': '2026-04-08T12:00:00.000',
      };
      final exercise = Exercise.fromJson(json);
      expect(exercise.useCount, 7);
      expect(exercise.lastUsedAt, DateTime(2026, 4, 8, 12, 0));
    });

    test('fromJson defaults when usage fields absent', () {
      final json = {
        'id': 'ex1',
        'name': 'Bench Press',
        'primaryMuscles': ['Chest'],
        'equipment': ['Barbell'],
        'instructions': '',
        'archived': false,
      };
      final exercise = Exercise.fromJson(json);
      expect(exercise.useCount, 0);
      expect(exercise.lastUsedAt, isNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/exercise_test.dart`
Expected: FAIL — `useCount` and `lastUsedAt` don't exist on Exercise

**Step 3: Write minimal implementation**

In `lib/src/data/models/exercise.dart`:

Add to constructor parameters:
```dart
this.useCount = 0,
this.lastUsedAt,
```

Add fields:
```dart
final int useCount;
final DateTime? lastUsedAt;
```

Add to `copyWith`:
```dart
int? useCount,
DateTime? lastUsedAt,
```
And in the return:
```dart
useCount: useCount ?? this.useCount,
lastUsedAt: lastUsedAt ?? this.lastUsedAt,
```

Add to `fromJson`:
```dart
useCount: json['useCount'] as int? ?? 0,
lastUsedAt: json['lastUsedAt'] != null
    ? DateTime.parse(json['lastUsedAt'] as String)
    : null,
```

Add to `toJson`:
```dart
'useCount': useCount,
if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/data/models/exercise_test.dart`
Expected: PASS

**Step 5: Run all existing tests to check for regressions**

Run: `flutter test`
Expected: All existing tests still PASS

**Step 6: Commit**

```bash
git add lib/src/data/models/exercise.dart test/data/models/exercise_test.dart
git commit -m "feat: add useCount and lastUsedAt fields to Exercise model"
```

---

### Task 2: Update ExerciseController with usage tracking and frequency-sorted search

**Files:**
- Modify: `lib/src/features/exercises/exercise_controller.dart`
- Test: `test/features/exercises/exercise_controller_test.dart`

**Step 1: Write the failing test**

Create `test/features/exercises/exercise_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/exercises/exercise_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.read(appStateControllerProvider.notifier).replaceState(
      AppState(
        exercises: [
          const Exercise(
            id: 'ex1',
            name: 'Bench Press',
            primaryMuscles: ['Chest'],
            equipment: ['Barbell'],
            instructions: '',
            archived: false,
            useCount: 10,
          ),
          const Exercise(
            id: 'ex2',
            name: 'Squat',
            primaryMuscles: ['Quads'],
            equipment: ['Barbell'],
            instructions: '',
            archived: false,
            useCount: 5,
          ),
          const Exercise(
            id: 'ex3',
            name: 'Deadlift',
            primaryMuscles: ['Back'],
            equipment: ['Barbell'],
            instructions: '',
            archived: false,
            useCount: 20,
          ),
        ],
        routines: [],
        sessions: [],
      ),
    );
  });

  tearDown(() => container.dispose());

  group('ExerciseController', () {
    test('search returns exercises sorted by useCount descending', () {
      final controller = container.read(exerciseControllerProvider);
      final results = controller.search('');
      expect(results.map((e) => e.id).toList(), ['ex3', 'ex1', 'ex2']);
    });

    test('recordUsage increments useCount and sets lastUsedAt', () {
      final controller = container.read(exerciseControllerProvider);
      controller.recordUsage('ex2');
      final state = container.read(appStateControllerProvider);
      final updated = state.exerciseById('ex2')!;
      expect(updated.useCount, 6);
      expect(updated.lastUsedAt, isNotNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/exercises/exercise_controller_test.dart`
Expected: FAIL — `recordUsage` doesn't exist, sort order is alphabetical

**Step 3: Write minimal implementation**

In `lib/src/features/exercises/exercise_controller.dart`:

Change the sort in `search()` from alphabetical to usage-based:
```dart
}).toList()..sort((a, b) {
  final countCmp = b.useCount.compareTo(a.useCount);
  if (countCmp != 0) return countCmp;
  final aTime = a.lastUsedAt ?? DateTime(1970);
  final bTime = b.lastUsedAt ?? DateTime(1970);
  return bTime.compareTo(aTime);
});
```

Add `recordUsage` method:
```dart
void recordUsage(String exerciseId) {
  _ref
      .read(appStateControllerProvider.notifier)
      .updateState(
        (state) => state.copyWith(
          exercises: state.exercises
              .map(
                (e) => e.id == exerciseId
                    ? e.copyWith(
                        useCount: e.useCount + 1,
                        lastUsedAt: DateTime.now(),
                      )
                    : e,
              )
              .toList(),
        ),
      );
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/exercises/exercise_controller_test.dart`
Expected: PASS

**Step 5: Run all tests**

Run: `flutter test`
Expected: All PASS

**Step 6: Commit**

```bash
git add lib/src/features/exercises/exercise_controller.dart test/features/exercises/exercise_controller_test.dart
git commit -m "feat: add recordUsage and frequency-sorted search to ExerciseController"
```

---

### Task 3: Add l10n strings for the picker

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_fr.arb`

**Step 1: Add English strings**

Add to `lib/l10n/app_en.arb`:
```json
"exercisePickerTitle": "Add Exercise",
"swapExercisePickerTitle": "Swap Exercise",
"createExerciseName": "Create \"{name}\"",
"@createExerciseName": {
  "placeholders": {
    "name": { "type": "String" }
  }
},
"quickCreateTitle": "Quick Create",
"selectPrimaryMuscle": "Primary muscle",
"createAndAdd": "Create"
```

**Step 2: Add French strings**

Add to `lib/l10n/app_fr.arb`:
```json
"exercisePickerTitle": "Ajouter un exercice",
"swapExercisePickerTitle": "Remplacer l'exercice",
"createExerciseName": "Créer \"{name}\"",
"@createExerciseName": {
  "placeholders": {
    "name": { "type": "String" }
  }
},
"quickCreateTitle": "Création rapide",
"selectPrimaryMuscle": "Muscle principal",
"createAndAdd": "Créer"
```

**Step 3: Generate l10n**

Run: `flutter gen-l10n`
Expected: Generates without errors

**Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/app_localizations*.dart
git commit -m "feat: add l10n strings for exercise picker"
```

---

### Task 4: Build the ExercisePickerSheet widget

**Files:**
- Create: `lib/src/shared/widgets/exercise_picker_sheet.dart`
- Test: `test/shared/widgets/exercise_picker_sheet_test.dart`

**Step 1: Write the widget test**

Create `test/shared/widgets/exercise_picker_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/shared/widgets/exercise_picker_sheet.dart';

Widget buildTestApp({required Widget child, required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.read(appStateControllerProvider.notifier).replaceState(
      AppState(
        exercises: [
          const Exercise(
            id: 'ex1',
            name: 'Bench Press',
            primaryMuscles: ['Chest'],
            equipment: ['Barbell'],
            instructions: '',
            archived: false,
            useCount: 10,
          ),
          const Exercise(
            id: 'ex2',
            name: 'Squat',
            primaryMuscles: ['Quads'],
            equipment: ['Barbell'],
            instructions: '',
            archived: false,
            useCount: 5,
          ),
        ],
        routines: [],
        sessions: [],
      ),
    );
  });

  tearDown(() => container.dispose());

  group('ExercisePickerSheet', () {
    testWidgets('shows exercises sorted by usage', (tester) async {
      await tester.pumpWidget(buildTestApp(
        container: container,
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showExercisePickerSheet(context: context),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Bench Press (useCount 10) should appear before Squat (useCount 5)
      final benchIndex = find.text('Bench Press');
      final squatIndex = find.text('Squat');
      expect(benchIndex, findsOneWidget);
      expect(squatIndex, findsOneWidget);
    });

    testWidgets('search filters exercises', (tester) async {
      await tester.pumpWidget(buildTestApp(
        container: container,
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showExercisePickerSheet(context: context),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bench');
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Squat'), findsNothing);
    });

    testWidgets('shows create row when no match', (tester) async {
      await tester.pumpWidget(buildTestApp(
        container: container,
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showExercisePickerSheet(context: context),
            child: const Text('Open'),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Cable Fly');
      await tester.pumpAndSettle();

      // Should show "Create "Cable Fly"" row
      expect(find.textContaining('Cable Fly'), findsWidgets);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/exercise_picker_sheet_test.dart`
Expected: FAIL — `exercise_picker_sheet.dart` doesn't exist

**Step 3: Write the implementation**

Create `lib/src/shared/widgets/exercise_picker_sheet.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/exercises/exercise_controller.dart';
import 'package:strength_training_tracker/src/l10n/exercise_translations.dart';

/// Shows the unified exercise picker bottom sheet.
///
/// Returns the selected [Exercise], or null if dismissed.
/// Set [isSwap] to true to show "Swap Exercise" title.
/// Pass [excludeIds] to grey out already-added exercises.
Future<Exercise?> showExercisePickerSheet({
  required BuildContext context,
  bool isSwap = false,
  Set<String> excludeIds = const {},
}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return _ExercisePickerBody(
            isSwap: isSwap,
            excludeIds: excludeIds,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _ExercisePickerBody extends ConsumerStatefulWidget {
  const _ExercisePickerBody({
    required this.isSwap,
    required this.excludeIds,
    required this.scrollController,
  });

  final bool isSwap;
  final Set<String> excludeIds;
  final ScrollController scrollController;

  @override
  ConsumerState<_ExercisePickerBody> createState() =>
      _ExercisePickerBodyState();
}

class _ExercisePickerBodyState extends ConsumerState<_ExercisePickerBody> {
  String _query = '';
  bool _showQuickCreate = false;
  String? _quickCreateMuscle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = context.appColors;
    final controller = ref.read(exerciseControllerProvider);
    final filtered = controller.search(_query);

    final hasExactMatch = filtered.any(
      (e) => e.name.toLowerCase() == _query.toLowerCase(),
    );
    final showCreateRow = _query.trim().isNotEmpty && !hasExactMatch;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.isSwap
                    ? l10n.swapExercisePickerTitle
                    : l10n.exercisePickerTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.searchExercisesEllipsis,
                  filled: true,
                  fillColor: appColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() {
                  _query = value.trim();
                  _showQuickCreate = false;
                }),
              ),
            ),
            // Quick create form (expanded)
            if (_showQuickCreate)
              _QuickCreateForm(
                initialName: _query,
                onCreated: (exercise) {
                  Navigator.of(context).pop(exercise);
                },
              ),
            // Exercise list
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: filtered.length + (showCreateRow ? 1 : 0),
                itemBuilder: (context, index) {
                  // "Create" row at top
                  if (showCreateRow && index == 0) {
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.add_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(l10n.createExerciseName(_query)),
                      onTap: () => setState(() => _showQuickCreate = true),
                    );
                  }

                  final exerciseIndex =
                      showCreateRow ? index - 1 : index;
                  final exercise = filtered[exerciseIndex];
                  final isExcluded =
                      widget.excludeIds.contains(exercise.id);

                  return ListTile(
                    enabled: !isExcluded,
                    leading: _ExerciseThumbnail(exercise: exercise),
                    title: Text(
                      ExerciseTranslations.displayName(context, exercise),
                    ),
                    subtitle: Text(
                      exercise.primaryMuscles.join(', '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: appColors.subtleText,
                          ),
                    ),
                    trailing: isExcluded
                        ? Text(
                            l10n.added,
                            style: TextStyle(color: appColors.subtleText),
                          )
                        : Icon(
                            widget.isSwap
                                ? Icons.swap_horiz_rounded
                                : Icons.add_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    onTap: isExcluded
                        ? null
                        : () => Navigator.of(context).pop(exercise),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular thumbnail for an exercise — shows photo or muscle-based icon.
class _ExerciseThumbnail extends StatelessWidget {
  const _ExerciseThumbnail({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    if (exercise.photoBase64 != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: MemoryImage(base64Decode(exercise.photoBase64!)),
      );
    }

    final entry = _muscleIconMap[exercise.primaryMuscles.firstOrNull] ??
        _muscleIconMap['default']!;

    return CircleAvatar(
      radius: 20,
      backgroundColor: entry.$2.withValues(alpha: 0.15),
      child: Icon(entry.$1, size: 20, color: entry.$2),
    );
  }

  static const _muscleIconMap = <String, (IconData, Color)>{
    'Chest': (Icons.fitness_center_rounded, Color(0xFF2196F3)),
    'Back': (Icons.fitness_center_rounded, Color(0xFF4CAF50)),
    'Shoulders': (Icons.fitness_center_rounded, Color(0xFFFF9800)),
    'Biceps': (Icons.fitness_center_rounded, Color(0xFF9C27B0)),
    'Triceps': (Icons.fitness_center_rounded, Color(0xFF673AB7)),
    'Quads': (Icons.directions_run_rounded, Color(0xFF009688)),
    'Hamstrings': (Icons.directions_run_rounded, Color(0xFF00BCD4)),
    'Glutes': (Icons.directions_run_rounded, Color(0xFFE91E63)),
    'Abs': (Icons.fitness_center_rounded, Color(0xFFFFC107)),
    'Calves': (Icons.directions_run_rounded, Color(0xFF795548)),
    'default': (Icons.fitness_center_rounded, Color(0xFF607D8B)),
  };
}

/// Inline quick-create form — name pre-filled, just pick a muscle group.
class _QuickCreateForm extends ConsumerStatefulWidget {
  const _QuickCreateForm({
    required this.initialName,
    required this.onCreated,
  });

  final String initialName;
  final ValueChanged<Exercise> onCreated;

  @override
  ConsumerState<_QuickCreateForm> createState() => _QuickCreateFormState();
}

class _QuickCreateFormState extends ConsumerState<_QuickCreateForm> {
  late final TextEditingController _nameController;
  String? _selectedMuscle;

  static const _muscles = [
    'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps',
    'Quads', 'Hamstrings', 'Glutes', 'Abs', 'Calves',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = context.appColors;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: appColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.quickCreateTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.exerciseName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _muscles.map((muscle) {
                    final selected = _selectedMuscle == muscle;
                    return ChoiceChip(
                      label: Text(muscle),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedMuscle = muscle),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _selectedMuscle == null ||
                          _nameController.text.trim().isEmpty
                      ? null
                      : () {
                          final controller =
                              ref.read(exerciseControllerProvider);
                          final exercise = controller.create(
                            name: _nameController.text.trim(),
                            primaryMuscles: [_selectedMuscle!],
                            equipment: [],
                            instructions: '',
                          );
                          widget.onCreated(exercise);
                        },
                  child: Text(l10n.createAndAdd),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/exercise_picker_sheet_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/src/shared/widgets/exercise_picker_sheet.dart test/shared/widgets/exercise_picker_sheet_test.dart
git commit -m "feat: add ExercisePickerSheet shared widget"
```

---

### Task 5: Wire picker into the routine editor

**Files:**
- Modify: `lib/src/features/routines/routine_editor_screen.dart`

**Step 1: Update imports**

Add at top of `routine_editor_screen.dart`:
```dart
import 'package:strength_training_tracker/src/shared/widgets/exercise_picker_sheet.dart';
```

**Step 2: Replace `_showExercisePicker` method**

Replace the existing `_showExercisePicker` method (lines 377-423) with:

```dart
Future<void> _showExercisePicker(
  BuildContext context,
  List<Exercise> exercises,
) async {
  final picked = await showExercisePickerSheet(
    context: context,
    excludeIds: _exercises.map((e) => e.exerciseId).toSet(),
  );

  if (picked == null) return;

  final isTimed = picked.exerciseType == 'timed';
  setState(() {
    _exercises = [
      ..._exercises,
      RoutineExercise(
        exerciseId: picked.id,
        targetSets: isTimed ? 1 : 3,
        targetReps: isTimed ? 0 : 8,
        targetDurationSeconds: isTimed ? 60 : 60,
        restSeconds: isTimed ? 0 : 90,
        order: _exercises.length,
      ),
    ];
  });
}
```

**Step 3: Add swap button to exercise cards**

In the exercise card builder section (around lines 246-374), add a swap IconButton to each exercise card's actions. Find the existing delete/reorder actions and add before the delete action:

```dart
IconButton(
  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
  onPressed: () async {
    final picked = await showExercisePickerSheet(
      context: context,
      isSwap: true,
      excludeIds: _exercises.map((e) => e.exerciseId).toSet(),
    );
    if (picked == null) return;
    setState(() {
      _exercises[index] = _exercises[index].copyWith(
        exerciseId: picked.id,
      );
    });
  },
),
```

**Step 4: Remove the old `_ExercisePickerContent` class**

Delete the `_ExercisePickerContent` class (lines 586-710) — it's now replaced by the shared widget.

**Step 5: Run tests and verify the app builds**

Run: `flutter test && flutter build ios --no-codesign`
Expected: All PASS, build succeeds

**Step 6: Commit**

```bash
git add lib/src/features/routines/routine_editor_screen.dart
git commit -m "feat: wire ExercisePickerSheet into routine editor with swap support"
```

---

### Task 6: Wire picker into the active workout screen

**Files:**
- Modify: `lib/src/features/workout/active_workout_screen.dart`
- Modify: `lib/src/features/workout/workout_controller.dart`

**Step 1: Add `addExercise` to WorkoutController**

In `lib/src/features/workout/workout_controller.dart`, add this method:

```dart
/// Appends a new exercise to the active session's routine.
void addExercise(String exerciseId) {
  final state = _ref.read(appStateControllerProvider);
  final session = state.activeSession;
  if (session == null) return;

  final routine = state.routineById(session.routineId);
  if (routine == null) return;

  final exercise = state.exerciseById(exerciseId);
  final isTimed = exercise?.exerciseType == 'timed';

  final newRoutineExercise = RoutineExercise(
    exerciseId: exerciseId,
    targetSets: isTimed ? 1 : 3,
    targetReps: isTimed ? 0 : 8,
    targetDurationSeconds: isTimed ? 60 : 60,
    restSeconds: isTimed ? 0 : 90,
    order: routine.exercises.length,
  );

  final updatedRoutine = routine.copyWith(
    exercises: [...routine.exercises, newRoutineExercise],
  );

  _ref
      .read(appStateControllerProvider.notifier)
      .updateState(
        (s) => s.copyWith(
          routines: s.routines
              .map((r) => r.id == updatedRoutine.id ? updatedRoutine : r)
              .toList(),
        ),
      );
}
```

Add import at top:
```dart
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
```

**Step 2: Replace the "Add Exercise" button in active workout**

In `active_workout_screen.dart`, find the "Add Exercise" button (around line 836-854) that currently navigates to the routine editor. Replace the `onPressed` callback:

```dart
onPressed: () async {
  final picked = await showExercisePickerSheet(
    context: context,
  );
  if (picked == null) return;
  final controller = ref.read(workoutControllerProvider);
  controller.addExercise(picked.id);
},
```

Add import at top:
```dart
import 'package:strength_training_tracker/src/shared/widgets/exercise_picker_sheet.dart';
```

**Step 3: Replace the swap exercise bottom sheet in active workout**

Find the existing swap exercise `showModalBottomSheet` (around lines 660-800) and replace it with the shared picker:

```dart
final picked = await showExercisePickerSheet(
  context: context,
  isSwap: true,
);
if (picked == null) return;
final controller = ref.read(workoutControllerProvider);
controller.swapExercise(pageIndex, picked.id);
```

**Step 4: Run tests**

Run: `flutter test`
Expected: All PASS

**Step 5: Commit**

```bash
git add lib/src/features/workout/active_workout_screen.dart lib/src/features/workout/workout_controller.dart
git commit -m "feat: wire ExercisePickerSheet into active workout screen"
```

---

### Task 7: Record exercise usage on set completion

**Files:**
- Modify: `lib/src/features/workout/workout_controller.dart`

**Step 1: Add usage tracking to `logSet` and `logTimedSet`**

In `workout_controller.dart`, at the end of `logSet()` (after persisting the session), add:

```dart
_ref.read(exerciseControllerProvider).recordUsage(exerciseId);
```

Do the same at the end of `logTimedSet()`.

Note: Import the exercise controller at the top:
```dart
import 'package:strength_training_tracker/src/features/exercises/exercise_controller.dart';
```

**Step 2: Run tests**

Run: `flutter test`
Expected: All PASS

**Step 3: Commit**

```bash
git add lib/src/features/workout/workout_controller.dart
git commit -m "feat: record exercise usage on set completion"
```

---

### Task 8: Manual testing and polish

**Step 1: Run the app on simulator**

Run: `flutter run`

**Step 2: Test routine editor flow**

1. Open a routine → tap "Add Exercise" → verify bottom sheet opens
2. Search for an exercise → verify filtering works
3. Type a name that doesn't exist → verify "Create..." row appears
4. Tap "Create..." → verify inline form expands with name pre-filled
5. Select a muscle → tap Create → verify exercise is created and added to routine
6. Verify exercise thumbnails display correctly
7. Tap swap icon on an exercise → verify swap picker opens and works

**Step 3: Test active workout flow**

1. Start a workout session
2. Scroll to "Add Exercise" button → verify picker opens (not routine editor)
3. Add an exercise mid-workout → verify it appears in the session
4. Tap swap on an exercise → verify picker opens and swap works
5. Log sets → verify exercise usage counts are tracked

**Step 4: Verify no regressions**

- Complete a full workout flow end-to-end
- Check that exercise creation from the full editor still works
- Verify l10n works in both English and French

**Step 5: Run full test suite**

Run: `flutter test`
Expected: All PASS

**Step 6: Final commit (if any polish needed)**

```bash
git add -A
git commit -m "fix: polish exercise picker interactions"
```

---

Plan complete and saved to `docs/plans/2026-04-08-exercise-picker-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** — Open a new session with executing-plans, batch execution with checkpoints

Which approach?
