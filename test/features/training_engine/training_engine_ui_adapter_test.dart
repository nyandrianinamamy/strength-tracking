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

  LoadRecommendation recommendation({
    required double suggestedWeightKg,
    required double previousWeightKg,
    required PerformanceDelta delta,
    GateResult gateResult = const GateResult.clear(),
  }) {
    return LoadRecommendation(
      exerciseId: 'barbell_bench_press',
      suggestedWeightKg: suggestedWeightKg,
      targets: const TargetParams(
        targetRepsLow: 8,
        targetRepsHigh: 12,
        targetRpe: 8.0,
      ),
      delta: delta,
      gateResult: gateResult,
      e1rm: 100,
      previousWeightKg: previousWeightKg,
      explanation: 'Engine explanation.',
    );
  }

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

  test('maps every default engine muscle to at least one heatmap region', () {
    for (final muscleId in defaultMuscles.keys) {
      final heatmapData = adapter.toHeatmapData({
        muscleId: FatigueStatus(level: 50, tau: 24),
      });

      expect(
        heatmapData,
        isNotEmpty,
        reason: '$muscleId should map to a closest heatmap region',
      );
    }
  });

  test('ignores unknown engine muscles when building heatmap data', () {
    final heatmapData = adapter.toHeatmapData({
      'custom_unmapped_muscle': FatigueStatus(level: 75, tau: 24),
    });

    expect(heatmapData, isEmpty);
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

  group(
    'maps recommendation direction from suggested load and safety gate',
    () {
      test('high fatigue reduction is down even when delta is maintenance', () {
        final suggestion = adapter.toWeightSuggestion(
          recommendation(
            suggestedWeightKg: 90,
            previousWeightKg: 100,
            delta: PerformanceDelta.maintenance,
            gateResult: const GateResult.blocked(
              reason: GateReason.muscleFatigue,
              action: GateAction.reduceLoad,
            ),
          ),
        );

        expect(suggestion!.direction, EngineSuggestionDirection.down);
      });

      test(
        'very high fatigue alternative is down even when delta is maintenance',
        () {
          final suggestion = adapter.toWeightSuggestion(
            recommendation(
              suggestedWeightKg: 80,
              previousWeightKg: 100,
              delta: PerformanceDelta.maintenance,
              gateResult: const GateResult.blocked(
                reason: GateReason.muscleFatigue,
                action: GateAction.suggestAlternative,
              ),
            ),
          );

          expect(suggestion!.direction, EngineSuggestionDirection.down);
        },
      );

      test('ACWR danger deload is down even when delta is maintenance', () {
        final suggestion = adapter.toWeightSuggestion(
          recommendation(
            suggestedWeightKg: 70,
            previousWeightKg: 100,
            delta: PerformanceDelta.maintenance,
            gateResult: const GateResult.blocked(
              reason: GateReason.acwrDanger,
              action: GateAction.deload,
            ),
          ),
        );

        expect(suggestion!.direction, EngineSuggestionDirection.down);
      });

      test(
        'low readiness reduction is down even when delta is maintenance',
        () {
          final suggestion = adapter.toWeightSuggestion(
            recommendation(
              suggestedWeightKg: 90,
              previousWeightKg: 100,
              delta: PerformanceDelta.maintenance,
              gateResult: const GateResult.blocked(
                reason: GateReason.lowReadiness,
                action: GateAction.reduceLoad,
              ),
            ),
          );

          expect(suggestion!.direction, EngineSuggestionDirection.down);
        },
      );

      test('clear maintenance with unchanged load is hold', () {
        final suggestion = adapter.toWeightSuggestion(
          recommendation(
            suggestedWeightKg: 100,
            previousWeightKg: 100,
            delta: PerformanceDelta.maintenance,
          ),
        );

        expect(suggestion!.direction, EngineSuggestionDirection.hold);
      });

      test('clear progression with increased load is up', () {
        final suggestion = adapter.toWeightSuggestion(
          recommendation(
            suggestedWeightKg: 102.5,
            previousWeightKg: 100,
            delta: PerformanceDelta.progression,
          ),
        );

        expect(suggestion!.direction, EngineSuggestionDirection.up);
      });
    },
  );

  group('maps active workout suggestion direction labels', () {
    EngineWeightSuggestion suggestion({
      required EngineSuggestionDirection direction,
      GateAction? gateAction,
    }) {
      return EngineWeightSuggestion(
        suggestedWeightKg: 100,
        direction: direction,
        reason: 'Engine explanation.',
        gateAction: gateAction,
      );
    }

    test('safety gate labels never display as hold steady', () {
      expect(
        engineSuggestionDirectionLabel(
          suggestion(
            direction: EngineSuggestionDirection.down,
            gateAction: GateAction.deload,
          ),
        ),
        'deload',
      );
      expect(
        engineSuggestionDirectionLabel(
          suggestion(
            direction: EngineSuggestionDirection.down,
            gateAction: GateAction.reduceLoad,
          ),
        ),
        'reduce load',
      );
      expect(
        engineSuggestionDirectionLabel(
          suggestion(
            direction: EngineSuggestionDirection.down,
            gateAction: GateAction.suggestAlternative,
          ),
        ),
        'alternative suggested',
      );
    });

    test(
      'direction labels distinguish true hold, progression, and reduction',
      () {
        expect(
          engineSuggestionDirectionLabel(
            suggestion(direction: EngineSuggestionDirection.hold),
          ),
          'hold steady',
        );
        expect(
          engineSuggestionDirectionLabel(
            suggestion(direction: EngineSuggestionDirection.up),
          ),
          'up from last time',
        );
        expect(
          engineSuggestionDirectionLabel(
            suggestion(direction: EngineSuggestionDirection.down),
          ),
          'reduce from last time',
        );
      },
    );
  });

  test(
    'engine suggestion provider returns null with no ingested sessions',
    () async {
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
        routineEngineWeightSuggestionProvider(const RoutineLoadRecommendationParams(exerciseId: 'barbell_bench_press', targetReps: 8, targetRpe: 8)).future,
      );

      expect(suggestion, isNull);
    },
  );
}
