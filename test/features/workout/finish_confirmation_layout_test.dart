import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/workout/active_workout_screen.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';

Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Lexend');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'Black']) {
      font.addFont(rootBundle.load('assets/fonts/Lexend-$weight.ttf'));
    }
    await font.load();
  });

  for (final scenario in [
    (inset: 0.0, action: 'Keep Training'),
    (inset: 260.0, action: 'Keep Training'),
    (inset: 260.0, action: 'Finish & Save'),
    (inset: 260.0, action: 'Discard Session'),
  ]) {
    testWidgets('finish sheet reaches ${scenario.action} at short height with '
        '${scenario.inset}px keyboard inset', (tester) async {
      // The iPad native failure had 327px of inner width and 302px of
      // available height after the default sheet cap and its 24px padding.
      tester.view.physicalSize = const Size(375, 622);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repository = MemoryAppStateRepository(
        initialState: DemoSeedData.initialState(),
      );
      final container = ProviderContainer(
        overrides: [
          appStateRepositoryProvider.overrideWithValue(repository),
          initialAppStateProvider.overrideWithValue(repository.state),
          trainingEngineStateRepositoryProvider.overrideWithValue(
            MemoryTrainingEngineStateRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final active = container
          .read(routineControllerProvider)
          .startSession('push_day');
      container
          .read(workoutControllerProvider)
          .logSet(weightKg: 80, reps: 6, rpe: 8);
      final priorHistory = container
          .read(appStateControllerProvider)
          .sessions
          .where((session) => session.id != active.id)
          .toList();
      final router = GoRouter(
        initialLocation: '/workout',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/workout',
            builder: (context, state) => const ActiveWorkoutScreen(),
          ),
          GoRoute(
            path: '/workout/:sessionId/summary',
            builder: (context, state) =>
                const Scaffold(body: Text('Saved workout summary')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await _pumpSheet(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('FINISH').last);
      await _pumpSheet(tester);
      expect(tester.takeException(), isNull);

      // Preserve the keyboard inset across the modal transition, including
      // the period before an on-screen keyboard has finished dismissing.
      tester.view.viewInsets = FakeViewPadding(bottom: scenario.inset);
      await _pumpSheet(tester);
      expect(tester.takeException(), isNull);

      for (final label in [
        'Finish & Save',
        'Keep Training',
        'Discard Session',
      ]) {
        final action = _button(label);
        await tester.ensureVisible(action);
        await _pumpSheet(tester);
        expect(action.hitTestable(), findsOneWidget);
        expect(
          tester.getBottomRight(action).dy,
          lessThanOrEqualTo(622 - scenario.inset),
          reason: '$label must be fully above the keyboard',
        );
        expect(tester.takeException(), isNull);
      }

      final chosenAction = _button(scenario.action);
      await tester.ensureVisible(chosenAction);
      await _pumpSheet(tester);
      await tester.tap(chosenAction);
      await _pumpSheet(tester);

      expect(find.byType(BottomSheet), findsNothing);
      final state = container.read(appStateControllerProvider);
      if (scenario.action == 'Keep Training') {
        expect(state.activeSession?.id, active.id);
        expect(state.activeSession?.completedSets.single.weightKg, 80);
        expect(router.routeInformationProvider.value.uri.path, '/workout');
      } else if (scenario.action == 'Finish & Save') {
        expect(state.activeSession, isNull);
        final completed = state.sessions.singleWhere(
          (session) => session.id == active.id,
        );
        expect(completed.endedAt, isNotNull);
        expect(completed.completedSets.single.weightKg, 80);
        expect(completed.completedSets.single.reps, 6);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/workout/${active.id}/summary',
        );
      } else {
        expect(state.activeSession, isNull);
        expect(
          state.sessions.where((session) => session.id != active.id),
          priorHistory,
        );
        expect(
          state.sessions
              .singleWhere((session) => session.id == active.id)
              .status,
          WorkoutSessionStatus.discarded,
        );
        expect(router.routeInformationProvider.value.uri.path, '/');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
