// test/features/smart_planner/widgets/plan_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_engine/training_engine.dart';

import 'package:strength_training_tracker/src/features/smart_planner/widgets/plan_preview.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/session_card.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

String _nameResolver(String id) => 'Exercise $id';

PlannedSession _makeSession({
  int dayOfWeek = 1,
  SessionFocus focus = SessionFocus.push,
}) {
  return PlannedSession(
    dayOfWeek: dayOfWeek,
    focus: focus,
    exercises: [
      const PlannedExercise(
        exerciseId: 'bench_press',
        targetSets: 3,
        targetReps: 10,
        targetRpe: 8.0,
        restSeconds: 90,
      ),
    ],
    estimatedDuration: const Duration(minutes: 45),
  );
}

WeeklyPlan _makePlan({
  SplitType splitType = SplitType.pushPullLegs,
  List<PlannedSession>? sessions,
}) {
  return WeeklyPlan(
    splitType: splitType,
    weekStart: DateTime(2026, 4, 7),
    sessions: sessions ??
        [
          _makeSession(dayOfWeek: 1, focus: SessionFocus.push),
          _makeSession(dayOfWeek: 3, focus: SessionFocus.pull),
          _makeSession(dayOfWeek: 5, focus: SessionFocus.legs),
        ],
  );
}

void main() {
  group('PlanPreview', () {
    testWidgets('1. renders split type header text for Push/Pull/Legs',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          PlanPreview(
            plan: _makePlan(splitType: SplitType.pushPullLegs),
            editedKeys: const {},
            exerciseNameResolver: _nameResolver,
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onExerciseSwapRequested: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onRegenerate: () {},
            onAdopt: () {},
          ),
        ),
      );

      expect(find.text('Push/Pull/Legs'), findsOneWidget);
    });

    testWidgets('2. renders split type header text for Full Body',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          PlanPreview(
            plan: _makePlan(
              splitType: SplitType.fullBody,
              sessions: [
                _makeSession(dayOfWeek: 1, focus: SessionFocus.fullBody),
              ],
            ),
            editedKeys: const {},
            exerciseNameResolver: _nameResolver,
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onExerciseSwapRequested: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onRegenerate: () {},
            onAdopt: () {},
          ),
        ),
      );

      expect(find.text('Full Body'), findsOneWidget);
    });

    testWidgets('3. renders split type header text for Upper/Lower',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          PlanPreview(
            plan: _makePlan(
              splitType: SplitType.upperLower,
              sessions: [
                _makeSession(dayOfWeek: 1, focus: SessionFocus.upper),
                _makeSession(dayOfWeek: 3, focus: SessionFocus.lower),
              ],
            ),
            editedKeys: const {},
            exerciseNameResolver: _nameResolver,
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onExerciseSwapRequested: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onRegenerate: () {},
            onAdopt: () {},
          ),
        ),
      );

      expect(find.text('Upper/Lower'), findsOneWidget);
    });

    testWidgets('4. renders correct number of SessionCard widgets',
        (tester) async {
      final plan = _makePlan(
        sessions: [
          _makeSession(dayOfWeek: 1, focus: SessionFocus.push),
          _makeSession(dayOfWeek: 3, focus: SessionFocus.pull),
          _makeSession(dayOfWeek: 5, focus: SessionFocus.legs),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          PlanPreview(
            plan: plan,
            editedKeys: const {},
            exerciseNameResolver: _nameResolver,
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onExerciseSwapRequested: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onRegenerate: () {},
            onAdopt: () {},
          ),
        ),
      );

      expect(find.byType(SessionCard), findsNWidgets(3));
    });

    testWidgets('5. Adopt button calls onAdopt callback', (tester) async {
      var adoptCalled = false;

      await tester.pumpWidget(
        _buildTestApp(
          PlanPreview(
            plan: _makePlan(),
            editedKeys: const {},
            exerciseNameResolver: _nameResolver,
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onExerciseSwapRequested: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onRegenerate: () {},
            onAdopt: () {
              adoptCalled = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Adopt Plan'));
      await tester.pump();

      expect(adoptCalled, isTrue);
    });

    testWidgets('6. Regenerate button calls onRegenerate callback',
        (tester) async {
      var regenerateCalled = false;

      await tester.pumpWidget(
        _buildTestApp(
          PlanPreview(
            plan: _makePlan(),
            editedKeys: const {},
            exerciseNameResolver: _nameResolver,
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onExerciseSwapRequested: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onRegenerate: () {
              regenerateCalled = true;
            },
            onAdopt: () {},
          ),
        ),
      );

      await tester.tap(find.text('Regenerate'));
      await tester.pump();

      expect(regenerateCalled, isTrue);
    });

    testWidgets('7. shows sessions per week subtitle', (tester) async {
      final plan = _makePlan(
        sessions: [
          _makeSession(dayOfWeek: 1),
          _makeSession(dayOfWeek: 3),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          PlanPreview(
            plan: plan,
            editedKeys: const {},
            exerciseNameResolver: _nameResolver,
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onExerciseSwapRequested: ({
              required int sessionIndex,
              required int exerciseIndex,
            }) {},
            onRegenerate: () {},
            onAdopt: () {},
          ),
        ),
      );

      expect(find.textContaining('2 sessions per week'), findsOneWidget);
    });
  });
}
