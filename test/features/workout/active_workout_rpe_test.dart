import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/workout/active_workout_screen.dart';

void main() {
  testWidgets('logging a strength set shows its per-set RPE in session history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = MemoryAppStateRepository(
      initialState: DemoSeedData.initialState(),
    );
    final container = ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
      ],
    );
    addTearDown(container.dispose);

    container.read(routineControllerProvider).startSession('push_day');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ActiveWorkoutScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('active-workout-weight-input')),
      '100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('active-workout-reps-input')),
      '6',
    );
    await tester.enterText(
      find.byKey(const ValueKey('active-workout-rpe-input')),
      '8.5',
    );

    await tester.tap(find.byKey(const ValueKey('active-workout-log-set-button')));
    await tester.pump();

    expect(find.textContaining('RPE 8.5'), findsOneWidget);
  });
}
