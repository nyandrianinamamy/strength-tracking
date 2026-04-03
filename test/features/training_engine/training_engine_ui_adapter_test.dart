import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_ui_adapter.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  const adapter = TrainingEngineUiAdapter();

  test('maps engine fatigue statuses to heatmap muscles', () {
    final heatmapData = adapter.toHeatmapData({
      'pectorals': FatigueStatus(level: 80, tau: 24),
      'anterior_deltoid': FatigueStatus(level: 35, tau: 16),
      'quadriceps': FatigueStatus(level: 60, tau: 24),
      'unknown_muscle': FatigueStatus(level: 90, tau: 24),
    });

    expect(heatmapData[Muscle.chest]?.intensity, closeTo(0.8, 0.001));
    expect(heatmapData[Muscle.deltoids]?.intensity, closeTo(0.35, 0.001));
    expect(heatmapData[Muscle.quadriceps]?.intensity, closeTo(0.6, 0.001));
    expect(heatmapData.containsKey(Muscle.triceps), isFalse);
  });

  test('maps engine load recommendation to app suggestion', () {
    final suggestion = adapter.toWeightSuggestion(
      const LoadRecommendation(
        exerciseId: 'barbell_bench_press',
        suggestedWeightKg: 82.5,
        targets: TargetParams(
          targetRepsLow: 8,
          targetRepsHigh: 12,
          targetRpe: 8.0,
        ),
        delta: PerformanceDelta.progression,
        gateResult: GateResult.clear(),
        e1rm: 100,
        previousWeightKg: 80,
        explanation: 'Increase load slightly.',
      ),
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.suggestedWeightKg, 82.5);
    expect(suggestion.direction, EngineSuggestionDirection.up);
    expect(suggestion.reason, 'Increase load slightly.');
  });

  test('engine suggestion provider returns null with no ingested sessions', () async {
    final initialState = const AppState(
      exercises: [],
      routines: [],
      routineGroups: [],
      sessions: [],
    );
    final container = ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(
          MemoryAppStateRepository(initialState: initialState),
        ),
        initialAppStateProvider.overrideWithValue(initialState),
        trainingEngineStateRepositoryProvider.overrideWithValue(
          MemoryTrainingEngineStateRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final suggestion = await container.read(
      engineWeightSuggestionProvider('barbell_bench_press').future,
    );

    expect(suggestion, isNull);
  });
}
