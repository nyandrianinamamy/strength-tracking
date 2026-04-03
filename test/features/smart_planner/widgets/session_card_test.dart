// test/features/smart_planner/widgets/session_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_engine/training_engine.dart';

import 'package:strength_training_tracker/src/features/smart_planner/widgets/session_card.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

String _nameResolver(String id) => 'Exercise $id';

PlannedSession _makeSession({
  int dayOfWeek = 1, // Monday
  SessionFocus focus = SessionFocus.push,
  int durationMinutes = 45,
  List<PlannedExercise>? exercises,
}) {
  return PlannedSession(
    dayOfWeek: dayOfWeek,
    focus: focus,
    exercises: exercises ??
        [
          const PlannedExercise(
            exerciseId: 'bench_press',
            targetSets: 3,
            targetReps: 10,
            targetRpe: 8.0,
            restSeconds: 90,
          ),
        ],
    estimatedDuration: Duration(minutes: durationMinutes),
  );
}

void main() {
  group('SessionCard', () {
    testWidgets('1. shows day name and focus label in title', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          SessionCard(
            session: _makeSession(dayOfWeek: 1, focus: SessionFocus.push),
            sessionIndex: 0,
            exerciseNameResolver: _nameResolver,
            editedKeys: const {},
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: (_) {},
            onExerciseSwapRequested: (_) {},
          ),
        ),
      );

      // Title should contain "Monday" and "Push"
      expect(find.textContaining('Monday'), findsOneWidget);
      expect(find.textContaining('Push'), findsOneWidget);
    });

    testWidgets('2. shows duration and exercise count in subtitle',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          SessionCard(
            session: _makeSession(durationMinutes: 45),
            sessionIndex: 0,
            exerciseNameResolver: _nameResolver,
            editedKeys: const {},
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: (_) {},
            onExerciseSwapRequested: (_) {},
          ),
        ),
      );

      expect(find.textContaining('45'), findsOneWidget);
      expect(find.textContaining('min'), findsOneWidget);
      expect(find.textContaining('1'), findsWidgets); // exercise count
    });

    testWidgets('3. shows exercise name when expanded', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          SessionCard(
            session: _makeSession(),
            sessionIndex: 0,
            exerciseNameResolver: _nameResolver,
            editedKeys: const {},
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: (_) {},
            onExerciseSwapRequested: (_) {},
          ),
        ),
      );

      // Expand the card
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Resolver returns "Exercise bench_press"
      expect(find.textContaining('Exercise bench_press'), findsOneWidget);
    });

    testWidgets('4. shows sets×reps info in exercise row when expanded',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          SessionCard(
            session: _makeSession(
              exercises: [
                const PlannedExercise(
                  exerciseId: 'squat',
                  targetSets: 4,
                  targetReps: 8,
                  targetRpe: 8.5,
                  restSeconds: 180,
                ),
              ],
            ),
            sessionIndex: 0,
            exerciseNameResolver: _nameResolver,
            editedKeys: const {},
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: (_) {},
            onExerciseSwapRequested: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Should show sets × reps (e.g., "4×8")
      expect(find.textContaining('4'), findsWidgets);
      expect(find.textContaining('8'), findsWidgets);
    });

    testWidgets('5. shows correct day name for Sunday (dayOfWeek=0)',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          SessionCard(
            session: _makeSession(dayOfWeek: 0, focus: SessionFocus.fullBody),
            sessionIndex: 0,
            exerciseNameResolver: _nameResolver,
            editedKeys: const {},
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: (_) {},
            onExerciseSwapRequested: (_) {},
          ),
        ),
      );

      expect(find.textContaining('Sunday'), findsOneWidget);
      expect(find.textContaining('Full Body'), findsOneWidget);
    });

    testWidgets('6. shows SS badge for superset exercise when expanded',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          SessionCard(
            session: _makeSession(
              exercises: [
                const PlannedExercise(
                  exerciseId: 'cable_fly',
                  targetSets: 3,
                  targetReps: 12,
                  targetRpe: 7.0,
                  restSeconds: 60,
                  isSupersetPair: true,
                ),
              ],
            ),
            sessionIndex: 0,
            exerciseNameResolver: _nameResolver,
            editedKeys: const {},
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: (_) {},
            onExerciseSwapRequested: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('SS'), findsOneWidget);
    });

    testWidgets('7. shows edit icon for keys in editedKeys when expanded',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          SessionCard(
            session: _makeSession(
              exercises: [
                const PlannedExercise(
                  exerciseId: 'bench_press',
                  targetSets: 3,
                  targetReps: 10,
                  targetRpe: 8.0,
                  restSeconds: 90,
                ),
              ],
            ),
            sessionIndex: 0,
            exerciseNameResolver: _nameResolver,
            editedKeys: const {'0:0'}, // sessionIndex:exerciseIndex
            onExerciseUpdated: ({
              required int sessionIndex,
              required int exerciseIndex,
              required int? sets,
              required int? reps,
            }) {},
            onExerciseRemoved: (_) {},
            onExerciseSwapRequested: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });
}
