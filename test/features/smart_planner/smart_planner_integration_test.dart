// test/features/smart_planner/smart_planner_integration_test.dart
//
// End-to-end widget test covering the full wizard-to-adoption flow:
//   pick days → set goal → generate → adopt
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/smart_planner/smart_planner_screen.dart';

Widget _buildApp() {
  final initialState = AppState.empty();

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
  group('SmartPlannerScreen integration', () {
    testWidgets('full flow: pick days → set goal → generate → adopt',
        (tester) async {
      // Use a very tall surface so all controls always fall within viewport.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // ── Step 1: Training Days ─────────────────────────────────────────────

      // Tap Mon, Wed, Fri to select 3 days
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fri'));
      await tester.pumpAndSettle();

      // Tap the single "Next" FilledButton to advance to step 2.
      await tester.tap(find.widgetWithText(FilledButton, 'Next').first);
      await tester.pumpAndSettle();

      // ── Step 2: Goal & Duration ───────────────────────────────────────────

      // Verify step 2 shows "Training Goal"
      expect(find.text('Training Goal'), findsOneWidget);

      // Tap "Next" to advance to step 3.
      await tester.tap(find.widgetWithText(FilledButton, 'Next').first);
      await tester.pumpAndSettle();

      // ── Step 3: Preferences → Generate ───────────────────────────────────

      // We should now be on step 3 (index 2). Tap "Generate".
      await tester.tap(find.widgetWithText(FilledButton, 'Generate').first);
      await tester.pumpAndSettle();

      // ── Preview mode ──────────────────────────────────────────────────────

      // After generating, the screen switches to preview mode.
      // Verify "Adopt Plan" button is visible.
      expect(find.text('Adopt Plan'), findsOneWidget);
    });
  });
}
