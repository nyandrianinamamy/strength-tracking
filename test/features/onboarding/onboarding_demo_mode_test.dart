import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';

void main() {
  Widget buildTestApp() {
    final repository = MemoryAppStateRepository(initialState: AppState.empty());

    return ProviderScope(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
        trainingEngineStateRepositoryProvider.overrideWithValue(
          MemoryTrainingEngineStateRepository(),
        ),
      ],
      child: const StrengthTrainingApp(),
    );
  }

  testWidgets('onboarding shows demo button and loads demo data on tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Ignore overflow errors from dashboard layout at small test sizes
    final origHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      origHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = origHandler);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Verify we're on onboarding (userName is empty)
    expect(find.text("Let's Get Started"), findsOneWidget);

    // Demo button should be visible
    expect(find.text('Explore with Demo Data'), findsOneWidget);

    // Tap the demo button
    await tester.tap(find.text('Explore with Demo Data'));
    await tester.pumpAndSettle();

    // Should navigate to dashboard — onboarding gone, demo user name visible
    expect(find.text("Let's Get Started"), findsNothing);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('demo button is always visible (no name required)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final origHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      origHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = origHandler);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Name field is empty
    final nameField = find.widgetWithText(TextField, 'Your name');
    expect(nameField, findsOneWidget);
    expect(tester.widget<TextField>(nameField).controller?.text, isEmpty);

    // "Next" button should be disabled (no name entered)
    final nextButton = find.widgetWithText(FilledButton, 'Next');
    expect(nextButton, findsOneWidget);
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    // Demo button is always enabled regardless of name
    final demoButton = find.widgetWithText(
      OutlinedButton,
      'Explore with Demo Data',
    );
    expect(demoButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(demoButton).onPressed, isNotNull);
  });
}
