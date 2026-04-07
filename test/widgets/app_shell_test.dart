import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';

void main() {
  Widget buildTestApp() {
    final repository = MemoryAppStateRepository(
      initialState: DemoSeedData.initialState(),
    );

    return ProviderScope(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
      ],
      child: const StrengthTrainingApp(),
    );
  }

  testWidgets('desktop width uses navigation rail and can route to exercises', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Workout Library'), findsNothing);
    expect(find.text('Alex'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('Exercises'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('New Exercise'), findsOneWidget);
  });

  testWidgets('mobile width uses bottom navigation bar', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
