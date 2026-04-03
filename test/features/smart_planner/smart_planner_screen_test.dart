// test/features/smart_planner/smart_planner_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/smart_planner/smart_planner_screen.dart';

Widget _buildApp() {
  const initialState = AppState(exercises: [], routines: [], sessions: []);

  return ProviderScope(
    overrides: [
      initialAppStateProvider.overrideWithValue(initialState),
      appStateRepositoryProvider.overrideWithValue(
        MemoryAppStateRepository(initialState: initialState),
      ),
    ],
    child: const MaterialApp(home: SmartPlannerScreen()),
  );
}

void main() {
  group('SmartPlannerScreen', () {
    testWidgets('1. shows step 1 (day picker) initially — Mon and Fri visible',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
    });

    testWidgets('2. Next button is disabled when no days selected',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // The Stepper renders controls for each step; check that ALL Next
      // buttons are disabled (none have an onPressed callback).
      final nextButtons = tester
          .widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
      expect(nextButtons, isNotEmpty);
      for (final button in nextButtons) {
        expect(button.onPressed, isNull);
      }
    });

    testWidgets(
        '3. Selecting days enables Next and advances to step 2 — shows Training Goal',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Tap Mon to select a day
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      // At least one Next button should now be enabled
      final nextButtons = tester
          .widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
      expect(nextButtons.any((b) => b.onPressed != null), isTrue);

      // Tap the first enabled Next button to advance to step 2
      final enabledNext = find.widgetWithText(FilledButton, 'Next').first;
      await tester.tap(enabledNext);
      await tester.pumpAndSettle();

      // Step 2 should show "Training Goal"
      expect(find.text('Training Goal'), findsOneWidget);
    });
  });
}
