import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/shared/widgets/exercise_picker_sheet.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Wraps the body widget inside a Scaffold so it can be pumped directly
// without going through the modal-bottom-sheet machinery.
Widget _buildPickerBody({
  required ProviderContainer container,
  bool isSwap = false,
  Set<String> excludeIds = const {},
}) {
  // We build a widget that opens the picker sheet via a button press so we
  // can properly test showExercisePickerSheet.
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
      darkTheme: ThemeData.dark().copyWith(extensions: [AppColors.dark]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open_picker'),
              onPressed: () => showExercisePickerSheet(
                context,
                isSwap: isSwap,
                excludeIds: excludeIds,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

ProviderContainer _makeContainer(AppState state) {
  final repo = MemoryAppStateRepository(initialState: state);
  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(repo),
      initialAppStateProvider.overrideWithValue(repo.state),
    ],
  );
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _bench = Exercise(
  id: 'ex1',
  name: 'Bench Press',
  primaryMuscles: ['Chest'],
  equipment: ['Barbell'],
  instructions: '',
  archived: false,
  useCount: 10,
);

const _squat = Exercise(
  id: 'ex2',
  name: 'Squat',
  primaryMuscles: ['Quads'],
  equipment: ['Barbell'],
  instructions: '',
  archived: false,
  useCount: 5,
);

const _deadlift = Exercise(
  id: 'ex3',
  name: 'Deadlift',
  primaryMuscles: ['Back'],
  equipment: ['Barbell'],
  instructions: '',
  archived: false,
  useCount: 20,
);

final _initialState = AppState(
  exercises: [_bench, _squat, _deadlift],
  routines: [],
  sessions: [],
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ExercisePickerSheet', () {
    testWidgets('shows exercises sorted by usage (highest useCount first)',
        (tester) async {
      final container = _makeContainer(_initialState);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildPickerBody(container: container),
      );
      await tester.pumpAndSettle();

      // Open the sheet
      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      // The sheet should be visible
      expect(find.text('Add Exercise'), findsOneWidget);

      // Verify exercises appear and are ordered by useCount descending:
      // Deadlift (20) > Bench Press (10) > Squat (5)
      final deadliftPos = tester.getTopLeft(find.text('Deadlift')).dy;
      final benchPos = tester.getTopLeft(find.text('Bench Press')).dy;
      final squatPos = tester.getTopLeft(find.text('Squat')).dy;

      expect(deadliftPos, lessThan(benchPos),
          reason: 'Deadlift (useCount 20) should appear before Bench Press (10)');
      expect(benchPos, lessThan(squatPos),
          reason: 'Bench Press (useCount 10) should appear before Squat (5)');
    });

    testWidgets('search filters exercises to matching ones', (tester) async {
      final container = _makeContainer(_initialState);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildPickerBody(container: container),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      // Type a search query
      await tester.enterText(find.byType(TextField), 'bench');
      // Wait for debounce (300 ms) + settle
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Deadlift'), findsNothing);
      expect(find.text('Squat'), findsNothing);
    });

    testWidgets(
        'shows "Create [query]" row when search has no exact match',
        (tester) async {
      final container = _makeContainer(_initialState);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildPickerBody(container: container),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Cable Curl');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Should show a "Create ..." row because 'Cable Curl' is not in the list
      expect(find.textContaining('Create'), findsOneWidget);
    });

    testWidgets('does NOT show create row when query exactly matches an exercise',
        (tester) async {
      final container = _makeContainer(_initialState);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildPickerBody(container: container),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      // Type the exact name (case-insensitive)
      await tester.enterText(find.byType(TextField), 'bench press');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // 'Create ...' should NOT be shown for exact match
      expect(find.textContaining('Create'), findsNothing);
    });

    testWidgets('shows swap title when isSwap is true', (tester) async {
      final container = _makeContainer(_initialState);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildPickerBody(container: container, isSwap: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      expect(find.text('Swap Exercise'), findsOneWidget);
      expect(find.text('Add Exercise'), findsNothing);
    });

    testWidgets('excluded exercises are shown greyed out with "Added" label',
        (tester) async {
      final container = _makeContainer(_initialState);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildPickerBody(
          container: container,
          excludeIds: {'ex1'}, // Bench Press
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      // The "Added" label should appear next to Bench Press
      expect(find.text('Added'), findsOneWidget);
    });

    testWidgets('tapping create row expands the quick-create form',
        (tester) async {
      final container = _makeContainer(_initialState);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildPickerBody(container: container),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Cable Curl');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Tap the create row
      await tester.tap(find.textContaining('Create'));
      await tester.pumpAndSettle();

      // Quick-create form should now be visible
      expect(find.text('Quick Create'), findsOneWidget);
      expect(find.text('Exercise Name'), findsOneWidget);
    });
  });
}
