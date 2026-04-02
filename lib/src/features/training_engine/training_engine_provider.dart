import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:training_engine/training_engine.dart';

import '../../core/app_state_controller.dart';
import '../../data/models/app_state.dart';
import 'training_engine_ui_adapter.dart';
import 'healthkit_data_source.dart';
import 'training_engine_adapter.dart';
import 'training_engine_state_repository.dart';

// ---------------------------------------------------------------------------
// Core engine provider
// ---------------------------------------------------------------------------

final trainingEngineAdapterProvider = Provider<TrainingEngineAdapter>(
  (ref) => const TrainingEngineAdapter(),
);

final trainingEngineUiAdapterProvider = Provider<TrainingEngineUiAdapter>(
  (ref) => const TrainingEngineUiAdapter(),
);

final healthKitDataSourceProvider = Provider<HealthKitDataSource>(
  (ref) => const HealthKitDataSource(),
);

final trainingEngineStateRepositoryProvider =
    Provider<TrainingEngineStateRepository>(
      (ref) => throw UnimplementedError(
        'trainingEngineStateRepositoryProvider must be overridden',
      ),
    );

Future<TrainingEngine> loadTrainingEngine({
  required AppState appState,
  required TrainingEngineAdapter adapter,
  required HealthKitDataSource healthKit,
  required TrainingEngineStateRepository repository,
}) async {
  final registry = ExerciseRegistry.withDefaults();
  for (final exercise in appState.exercises) {
    final engineExercise = adapter.toEngineExercise(exercise, registry);
    if (engineExercise != null) {
      registry.addCustom(engineExercise);
    }
  }

  final profile = adapter.toUserProfile(appState);
  final engine = TrainingEngine(registry: registry, profile: profile);
  try {
    final savedState = await repository.load();
    if (savedState != null) {
      engine.restoreState(savedState);
      return engine;
    }
  } catch (error) {
    debugPrint(
      'Training engine restore failed, clearing saved state and rebuilding from app history: $error',
    );
    try {
      await repository.clear();
    } catch (clearError) {
      debugPrint(
        'Training engine state clear failed after restore error: $clearError',
      );
    }
  }

  final completedSessions = appState.completedSessions
      .map(adapter.toEngineSession)
      .whereType<EngineSession>()
      .toList();
  if (completedSessions.isNotEmpty) {
    engine.bootstrapFromHistory(completedSessions);
  }

  final sleepRecords = await healthKit.fetchRecentSleep();
  for (final record in sleepRecords) {
    engine.ingestSleep(record);
  }

  final hrvRecords = await healthKit.fetchRecentHrv();
  for (final record in hrvRecords) {
    engine.ingestHrv(record);
  }

  await repository.save(engine.serializeState());
  return engine;
}

final trainingEngineProvider = FutureProvider<TrainingEngine>((ref) async {
  final appState = ref.watch(appStateControllerProvider);
  final adapter = ref.watch(trainingEngineAdapterProvider);
  final healthKit = ref.watch(healthKitDataSourceProvider);
  final repository = ref.watch(trainingEngineStateRepositoryProvider);

  return loadTrainingEngine(
    appState: appState,
    adapter: adapter,
    healthKit: healthKit,
    repository: repository,
  );
});

// ---------------------------------------------------------------------------
// Derived providers
// ---------------------------------------------------------------------------

/// Returns the current per-muscle fatigue map.
final fatigueMapProvider = FutureProvider<Map<String, FatigueStatus>>((
  ref,
) async {
  final engine = await ref.watch(trainingEngineProvider.future);
  return engine.fullFatigueMap();
});

final engineHeatmapDataProvider = FutureProvider<Map<Muscle, MuscleData>>((
  ref,
) async {
  final engine = await ref.watch(trainingEngineProvider.future);
  if (engine.state.sessionsIngested == 0) {
    return <Muscle, MuscleData>{};
  }

  final fatigueMap = await ref.watch(fatigueMapProvider.future);
  return ref.watch(trainingEngineUiAdapterProvider).toHeatmapData(fatigueMap);
});

/// Returns the current composite readiness score.
final readinessProvider = FutureProvider<ReadinessScore>((ref) async {
  final engine = await ref.watch(trainingEngineProvider.future);
  return engine.computeReadiness();
});

/// Clears persisted engine state and re-bootstraps from AppState history.
///
/// This forces the engine to rebuild all e1RM estimates, fatigue impulses,
/// and ACWR from scratch using the corrected adapter normalization.
Future<void> resetAndRebootstrapEngine(WidgetRef ref) async {
  final repository = ref.read(trainingEngineStateRepositoryProvider);
  await repository.clear();
  ref.invalidate(trainingEngineProvider);
}

/// Returns a [LoadRecommendation] for the given exercise ID, or `null` when
/// no e1RM data is available (engine falls back to baseline, so this will
/// always return a recommendation in practice, but guards against edge cases).
final loadRecommendationProvider =
    FutureProvider.family<LoadRecommendation?, String>((ref, exerciseId) async {
      final engine = await ref.watch(trainingEngineProvider.future);
      // currentE1rm always returns a value (falls back to baseline), so this
      // check is a safety guard for truly degenerate states.
      if (engine.currentE1rm(exerciseId) == null) return null;
      return engine.recommendLoad(exerciseId);
    });

final engineWeightSuggestionProvider =
    FutureProvider.family<EngineWeightSuggestion?, String>((
      ref,
      exerciseId,
    ) async {
      final engine = await ref.watch(trainingEngineProvider.future);
      if (engine.state.sessionsIngested == 0) {
        return null;
      }

      final recommendation = engine.recommendLoad(exerciseId);
      return ref
          .watch(trainingEngineUiAdapterProvider)
          .toWeightSuggestion(recommendation);
    });

class EngineDebugFatigueRow {
  const EngineDebugFatigueRow({
    required this.muscleId,
    required this.value,
    required this.status,
  });

  final String muscleId;
  final double value;
  final FatigueStatus status;
}

class EngineDebugRecommendationRow {
  const EngineDebugRecommendationRow({
    required this.exerciseId,
    required this.exerciseName,
    required this.e1rm,
    required this.lastTopSet,
    required this.recommendation,
  });

  final String exerciseId;
  final String exerciseName;
  final double? e1rm;
  final LoggedSet? lastTopSet;
  final LoadRecommendation recommendation;
}

class EngineDebugDailyLoadSummary {
  const EngineDebugDailyLoadSummary({required this.date, required this.volume});

  final String date;
  final String volume;
}

class EngineDebugTextRow {
  const EngineDebugTextRow({required this.label, required this.value});

  final String label;
  final String value;
}

class EngineDebugCountRow {
  const EngineDebugCountRow({required this.label, required this.count});

  final String label;
  final int count;
}

class EngineDebugPersistedStateSummary {
  const EngineDebugPersistedStateSummary({
    required this.acwrSummary,
    required this.dailyLoadsCount,
    required this.lastTopSetsCount,
    required this.e1rmHistoryCount,
    required this.latestDailyLoad,
    required this.lastTopSetRows,
    required this.e1rmHistoryRows,
  });

  final String acwrSummary;
  final int dailyLoadsCount;
  final int lastTopSetsCount;
  final int e1rmHistoryCount;
  final EngineDebugDailyLoadSummary? latestDailyLoad;
  final List<EngineDebugTextRow> lastTopSetRows;
  final List<EngineDebugCountRow> e1rmHistoryRows;
}

final engineDebugPersistedStateSummaryProvider =
    FutureProvider<EngineDebugPersistedStateSummary>((ref) async {
      final engine = await ref.watch(trainingEngineProvider.future);
      final state = engine.state;

      final acwrState = state.acwrState;
      final acwrSummary = acwrState == null
          ? 'Unavailable'
          : 'acute ${acwrState.acuteEwma.toStringAsFixed(1)} / '
                'chronic ${acwrState.chronicEwma.toStringAsFixed(1)}';

      final dailyLoads = state.dailyLoads;
      final latestDailyLoad = dailyLoads.isEmpty
          ? null
          : EngineDebugDailyLoadSummary(
              date: dailyLoads.last.date.toIso8601String(),
              volume: dailyLoads.last.volumeLoad.toStringAsFixed(1),
            );

      String resolveName(String id) =>
          engine.registry.lookup(id)?.name ?? id;

      final lastTopSetRows = state.lastTopSets.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final e1rmHistoryRows = state.e1rmHistory.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      return EngineDebugPersistedStateSummary(
        acwrSummary: acwrSummary,
        dailyLoadsCount: dailyLoads.length,
        lastTopSetsCount: lastTopSetRows.length,
        e1rmHistoryCount: e1rmHistoryRows.length,
        latestDailyLoad: latestDailyLoad,
        lastTopSetRows: lastTopSetRows
            .map(
              (entry) => EngineDebugTextRow(
                label: resolveName(entry.key),
                value: _formatLoggedSet(entry.value),
              ),
            )
            .toList(),
        e1rmHistoryRows: e1rmHistoryRows
            .map(
              (entry) => EngineDebugCountRow(
                label: resolveName(entry.key),
                count: entry.value.length,
              ),
            )
            .toList(),
      );
    });

final engineDebugFatigueRowsProvider =
    FutureProvider<List<EngineDebugFatigueRow>>((ref) async {
      final engine = await ref.watch(trainingEngineProvider.future);
      final now = DateTime.now();
      final fatigueMap = engine.fullFatigueMap(now);
      final rows = fatigueMap.entries.map((entry) {
        return EngineDebugFatigueRow(
          muscleId: entry.key,
          value: engine.currentFatigue(entry.key, now),
          status: entry.value,
        );
      }).toList()..sort((a, b) => b.value.compareTo(a.value));
      return rows;
    });

final engineDebugRecommendationRowsProvider =
    FutureProvider<List<EngineDebugRecommendationRow>>((ref) async {
      final engine = await ref.watch(trainingEngineProvider.future);
      final rows = engine.state.lastTopSets.entries.map((entry) {
        final name =
            engine.registry.lookup(entry.key)?.name ?? entry.key;
        return EngineDebugRecommendationRow(
          exerciseId: entry.key,
          exerciseName: name,
          e1rm: engine.currentE1rm(entry.key),
          lastTopSet: entry.value,
          recommendation: engine.recommendLoad(entry.key),
        );
      }).toList()..sort((a, b) => a.exerciseName.compareTo(b.exerciseName));
      return rows;
    });

final engineDebugRawSnapshotProvider = FutureProvider<String>((ref) async {
  final engine = await ref.watch(trainingEngineProvider.future);
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(engine.serializeState());
});

String _formatLoggedSet(LoggedSet set) {
  return '${set.weightKg.toStringAsFixed(1)} kg × ${set.reps} @ ${set.rpe.toStringAsFixed(1)}';
}
