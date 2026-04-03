// test/features/smart_planner/widgets/goal_duration_step_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/goal_duration_step.dart';
import 'package:training_engine/training_engine.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

void main() {
  group('GoalDurationStep', () {
    testWidgets('1. renders 3 goal options (Hypertrophy, Strength, General)',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          GoalDurationStep(
            goal: HypertrophyGoal.hypertrophy,
            durationMinutes: 60,
            onGoalChanged: (_) {},
            onDurationChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Hypertrophy'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('2. tapping a goal calls onGoalChanged with correct value',
        (tester) async {
      HypertrophyGoal? changedGoal;

      await tester.pumpWidget(
        _buildTestApp(
          GoalDurationStep(
            goal: HypertrophyGoal.hypertrophy,
            durationMinutes: 60,
            onGoalChanged: (g) => changedGoal = g,
            onDurationChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Strength'));
      await tester.pump();

      expect(changedGoal, equals(HypertrophyGoal.strength));
    });

    testWidgets('3. displays current duration text (e.g., "90 min")',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          GoalDurationStep(
            goal: HypertrophyGoal.hypertrophy,
            durationMinutes: 90,
            onGoalChanged: (_) {},
            onDurationChanged: (_) {},
          ),
        ),
      );

      expect(find.text('90 min'), findsOneWidget);
    });
  });
}
