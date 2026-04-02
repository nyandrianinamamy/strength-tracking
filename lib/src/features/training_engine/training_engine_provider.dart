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
  final savedState = await repository.load();

  if (savedState != null) {
    engine.restoreState(savedState);
    return engine;
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
final fatigueMapProvider = FutureProvider<Map<String, FatigueStatus>>((ref) async {
  final engine = await ref.watch(trainingEngineProvider.future);
  return engine.fullFatigueMap();
});

final engineHeatmapDataProvider = FutureProvider<Map<Muscle, MuscleData>>((ref) async {
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
    FutureProvider.family<EngineWeightSuggestion?, String>((ref, exerciseId) async {
  final engine = await ref.watch(trainingEngineProvider.future);
  if (engine.state.sessionsIngested == 0) {
    return null;
  }

  final recommendation = engine.recommendLoad(exerciseId);
  return ref
      .watch(trainingEngineUiAdapterProvider)
      .toWeightSuggestion(recommendation);
});
