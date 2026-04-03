import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/preference_step.dart';

Exercise _makeExercise(String id, String name) => Exercise(
      id: id,
      name: name,
      primaryMuscles: const [],
      secondaryMuscles: const [],
      equipment: const [],
      instructions: '',
      archived: false,
      exerciseType: 'strength',
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final exercises = [
    _makeExercise('ex1', 'Bench Press'),
    _makeExercise('ex2', 'Squat'),
    _makeExercise('ex3', 'Deadlift'),
  ];

  testWidgets('renders exercise names from the provided list', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: PreferenceStep(
            exercises: exercises,
            preferredIds: const [],
            excludedIds: const [],
            onPreferredChanged: (_) {},
            onExcludedChanged: (_) {},
          ),
        ),
      ),
    );

    // Each exercise name should appear twice: once in Preferred, once in Excluded
    expect(find.text('Bench Press'), findsNWidgets(2));
    expect(find.text('Squat'), findsNWidgets(2));
    expect(find.text('Deadlift'), findsNWidgets(2));

    // Section headers
    expect(find.text('Preferred Exercises'), findsOneWidget);
    expect(find.text('Excluded Exercises'), findsOneWidget);
  });

  testWidgets('tapping a preferred exercise checkbox calls onPreferredChanged',
      (tester) async {
    List<String>? capturedPreferred;

    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: PreferenceStep(
            exercises: exercises,
            preferredIds: const [],
            excludedIds: const [],
            onPreferredChanged: (ids) => capturedPreferred = ids,
            onExcludedChanged: (_) {},
          ),
        ),
      ),
    );

    // The preferred section checkboxes come before the divider.
    // Find the first CheckboxListTile containing 'Bench Press' (preferred section).
    final preferredSection = find.byType(CheckboxListTile).first;
    await tester.tap(preferredSection);
    await tester.pump();

    expect(capturedPreferred, isNotNull);
    expect(capturedPreferred, contains('ex1'));
  });

  testWidgets('tapping excluded checkbox calls onExcludedChanged',
      (tester) async {
    List<String>? capturedExcluded;

    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: PreferenceStep(
            exercises: exercises,
            preferredIds: const [],
            excludedIds: const [],
            onPreferredChanged: (_) {},
            onExcludedChanged: (ids) => capturedExcluded = ids,
          ),
        ),
      ),
    );

    // Excluded section checkboxes start after the first 3 (one per exercise in preferred).
    final allCheckboxes = find.byType(CheckboxListTile);
    // Tap the 4th checkbox (first one in the excluded section)
    await tester.tap(allCheckboxes.at(3));
    await tester.pump();

    expect(capturedExcluded, isNotNull);
    expect(capturedExcluded, contains('ex1'));
  });

  testWidgets(
      'selecting preferred removes exercise from excluded (mutual exclusion)',
      (tester) async {
    List<String> currentPreferred = [];
    List<String> currentExcluded = ['ex1'];

    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => PreferenceStep(
              exercises: exercises,
              preferredIds: currentPreferred,
              excludedIds: currentExcluded,
              onPreferredChanged: (ids) =>
                  setState(() => currentPreferred = ids),
              onExcludedChanged: (ids) => setState(() => currentExcluded = ids),
            ),
          ),
        ),
      ),
    );

    // Tap first checkbox in preferred section (ex1 which is currently excluded)
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();

    expect(currentPreferred, contains('ex1'));
    expect(currentExcluded, isNot(contains('ex1')));
  });

  testWidgets(
      'selecting excluded removes exercise from preferred (mutual exclusion)',
      (tester) async {
    List<String> currentPreferred = ['ex1'];
    List<String> currentExcluded = [];

    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => PreferenceStep(
              exercises: exercises,
              preferredIds: currentPreferred,
              excludedIds: currentExcluded,
              onPreferredChanged: (ids) =>
                  setState(() => currentPreferred = ids),
              onExcludedChanged: (ids) => setState(() => currentExcluded = ids),
            ),
          ),
        ),
      ),
    );

    // Tap first checkbox in excluded section (ex1 which is currently preferred)
    await tester.tap(find.byType(CheckboxListTile).at(3));
    await tester.pump();

    expect(currentExcluded, contains('ex1'));
    expect(currentPreferred, isNot(contains('ex1')));
  });
}
