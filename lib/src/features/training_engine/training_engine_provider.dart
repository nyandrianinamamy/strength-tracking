import 'dart:convert';

import 'package:crypto/crypto.dart';

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

/// Auth transitions replace this immutable repository before replacing app state.
final accountTrainingEngineRepositoryProvider =
    StateProvider<TrainingEngineStateRepository?>((ref) => null);

final activeTrainingEngineStateRepositoryProvider =
    Provider<TrainingEngineStateRepository>(
      (ref) =>
          ref.watch(accountTrainingEngineRepositoryProvider) ??
          ref.watch(trainingEngineStateRepositoryProvider),
    );

/// Versioned digest of canonical source facts, independent of collection/map
/// order and the wall-clock profile creation timestamp.
String trainingHistoryFingerprint(
  AppState appState,
  TrainingEngineAdapter adapter,
) {
  final sessions = appState.completedSessions.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final exercises = appState.exercises.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final profile = adapter.toUserProfile(appState).toJson()..remove('createdAt');
  final payload = {
    'version': 2,
    'sessions': sessions
        .map(
          (s) => {
            'id': s.id,
            'startedAt': s.startedAt.toIso8601String(),
            'endedAt': s.endedAt?.toIso8601String(),
            'rpe': s.rpe,
            'sets': s.completedSets
                .map(
                  (set) => {
                    'exerciseId': set.exerciseId,
                    'weightKg': set.weightKg,
                    'reps': set.reps,
                    'durationSeconds': set.durationSeconds,
                    'rpe': set.rpe,
                    'completedAt': set.completedAt.toIso8601String(),
                  },
                )
                .toList(),
          },
        )
        .toList(),
    'exercises': exercises
        .map(
          (e) => {
            'id': e.id,
            'name': e.name,
            'primaryMuscles': e.primaryMuscles,
            'secondaryMuscles': e.secondaryMuscles,
            'equipment': e.equipment,
            'exerciseType': e.exerciseType,
          },
        )
        .toList(),
    'profile': profile,
  };
  return sha256
      .convert(utf8.encode(jsonEncode(_canonicalJson(payload))))
      .toString();
}

Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonicalJson(value[key])};
  }
  if (value is List) return value.map(_canonicalJson).toList();
  return value;
}

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
  final completedSessions = appState.completedSessions
      .map((session) => adapter.toEngineSession(session, registry: registry))
      .whereType<EngineSession>()
      .toList();
  final fingerprint = trainingHistoryFingerprint(appState, adapter);
  Future<void> save(TrainingEngine value) => repository.save({
    ...value.serializeState(),
    'historyFingerprint': fingerprint,
  });
  try {
    final savedState = await repository.load();
    if (savedState != null) {
      engine.restoreState(savedState);
      final profileWasUpdated = _refreshRestoredProfile(engine, profile);
      if (savedState['historyFingerprint'] == fingerprint) {
        if (profileWasUpdated) await save(engine);
        return engine;
      }

      final rebuilt = TrainingEngine(registry: registry, profile: profile);
      rebuilt.bootstrapFromHistory(completedSessions);
      _preserveHealthKitState(rebuilt, engine.state);
      await save(rebuilt);
      return rebuilt;
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

  if (completedSessions.isNotEmpty) {
    engine.bootstrapFromHistory(completedSessions);
  }

  if (appState.healthKitEnabled) {
    final sleepResult = await healthKit.fetchRecentSleepResult();
    final hrvResult = await healthKit.fetchRecentHrvResult();
    final sleepRecords = sleepResult.records;
    final hrvRecords = hrvResult.records;

    for (final record in sleepRecords) {
      engine.ingestSleep(record);
    }

    for (final record in hrvRecords) {
      engine.ingestHrv(record);
    }

    if (sleepResult.shouldStampFetch || hrvResult.shouldStampFetch) {
      engine.stampHealthKitFetch();
    }
  }

  await save(engine);
  return engine;
}

bool _refreshRestoredProfile(
  TrainingEngine engine,
  UserProfile currentProfile,
) {
  final restoredProfile = engine.state.profile;
  final refreshedProfile = currentProfile.copyWith(
    createdAt: restoredProfile.createdAt,
  );
  if (_sameProfile(restoredProfile, refreshedProfile)) {
    return false;
  }

  engine.restoreState(
    engine.state.copyWith(profile: refreshedProfile).toJson(),
  );
  return true;
}

bool _sameProfile(UserProfile left, UserProfile right) {
  return left.sex == right.sex &&
      left.age == right.age &&
      left.bodyWeightKg == right.bodyWeightKg &&
      left.experience == right.experience &&
      left.goal == right.goal &&
      listEquals(left.availableDays, right.availableDays) &&
      left.maxSessionDuration == right.maxSessionDuration &&
      left.createdAt == right.createdAt;
}

void _preserveHealthKitState(
  TrainingEngine rebuilt,
  TrainingState restoredState,
) {
  rebuilt.restoreState(
    rebuilt.state
        .copyWith(
          sleepHistory: restoredState.sleepHistory,
          hrvHistory: restoredState.hrvHistory,
          lastHealthKitFetch: restoredState.lastHealthKitFetch,
        )
        .toJson(),
  );
}

final trainingEngineProvider = FutureProvider<TrainingEngine>((ref) async {
  final appState = ref.watch(appStateControllerProvider);
  final adapter = ref.watch(trainingEngineAdapterProvider);
  final healthKit = ref.watch(healthKitDataSourceProvider);
  final repository = ref.watch(activeTrainingEngineStateRepositoryProvider);

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

/// Returns the engine-owned current rolling e1RM for exercises with strength
/// history. Timed exercises do not create e1RM history and are intentionally
/// absent from this map.
final engineCurrentE1rmsProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final engine = await ref.watch(trainingEngineProvider.future);
  final currentE1rms = <String, double>{};
  for (final exerciseId in engine.state.e1rmHistory.keys) {
    final current = engine.currentE1rm(exerciseId);
    if (current != null) {
      currentE1rms[exerciseId] = current;
    }
  }
  return currentE1rms;
});

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

/// Returns heatmap data that includes real-time fatigue from the active
/// workout session. Falls back to [engineHeatmapDataProvider] when there
/// is no active session or no logged sets.
final liveEngineHeatmapDataProvider = FutureProvider<Map<Muscle, MuscleData>>((
  ref,
) async {
  final appState = ref.watch(appStateControllerProvider);
  final activeSession = appState.activeSession;
  final activeSets = activeSession?.completedSets ?? [];

  // No active workout — use the standard engine-only heatmap
  if (activeSets.isEmpty) {
    return ref.watch(engineHeatmapDataProvider.future);
  }

  final engine = await ref.watch(trainingEngineProvider.future);
  final adapter = ref.watch(trainingEngineAdapterProvider);

  // Convert app CompletedSets to engine LoggedSets
  final engineSets = activeSets
      .where((s) => adapter.shouldMapSet(s, registry: engine.registry))
      .map(
        (s) => adapter.toLoggedSet(
          s,
          sessionRpe: activeSession?.rpe,
          exercise: engine.registry.lookup(s.exerciseId),
        ),
      )
      .toList();

  final fatigueMap = engine.previewFatigueWithSets(engineSets);
  return ref.watch(trainingEngineUiAdapterProvider).toHeatmapData(fatigueMap);
});

/// Returns the current composite readiness score.
///
/// Refreshes HealthKit data if stale (>1 hour since last fetch) before
/// computing, so the score always reflects recent sleep and HRV data.
final readinessProvider = FutureProvider<ReadinessScore>((ref) async {
  final appState = ref.watch(appStateControllerProvider);
  final healthKit = ref.watch(healthKitDataSourceProvider);
  final repository = ref.watch(activeTrainingEngineStateRepositoryProvider);
  final adapter = ref.watch(trainingEngineAdapterProvider);
  final engine = await ref.watch(trainingEngineProvider.future);

  if (appState.healthKitEnabled) {
    await engine.refreshHealthKitIfStale(
      fetchSleep: () => healthKit.fetchRecentSleep(),
      fetchHrv: () => healthKit.fetchRecentHrv(),
      threshold: _healthKitRefreshThreshold(engine),
    );

    // Persist updated state after refresh
    await repository.save({
      ...engine.serializeState(),
      'historyFingerprint': trainingHistoryFingerprint(appState, adapter),
    });
  }

  return engine.computeReadiness();
});

Duration _healthKitRefreshThreshold(TrainingEngine engine) {
  return const Duration(hours: 1);
}

/// Clears persisted engine state and re-bootstraps from AppState history.
///
/// This forces the engine to rebuild all e1RM estimates, fatigue impulses,
/// and ACWR from scratch using the corrected adapter normalization.
Future<void> resetAndRebootstrapEngine(WidgetRef ref) async {
  final repository = ref.read(activeTrainingEngineStateRepositoryProvider);
  await repository.clear();
  ref.invalidate(trainingEngineProvider);
}

@immutable
class RoutineLoadRecommendationParams {
  const RoutineLoadRecommendationParams({
    required this.exerciseId,
    required this.targetReps,
    this.targetRpe = 8.0,
  });

  final String exerciseId;
  final int targetReps;
  final double targetRpe;

  TargetParams get targetParams {
    final reps = targetReps < 1 ? 1 : targetReps;
    return TargetParams(
      targetRepsLow: reps,
      targetRepsHigh: reps,
      targetRpe: targetRpe,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RoutineLoadRecommendationParams &&
        other.exerciseId == exerciseId &&
        other.targetReps == targetReps &&
        other.targetRpe == targetRpe;
  }

  @override
  int get hashCode => Object.hash(exerciseId, targetReps, targetRpe);
}

/// Returns a routine-aware [LoadRecommendation].
///
/// Routine prescriptions do not currently model target RPE, so callers pass an
/// explicit default of 8.0 through [RoutineLoadRecommendationParams].
final routineLoadRecommendationProvider =
    FutureProvider.family<LoadRecommendation?, RoutineLoadRecommendationParams>(
      (ref, params) async {
        final engine = await ref.watch(trainingEngineProvider.future);
        if (engine.state.sessionsIngested == 0) {
          return null;
        }

        if (engine.currentE1rm(params.exerciseId) == null) return null;
        return engine.recommendLoad(
          params.exerciseId,
          overrides: params.targetParams,
        );
      },
    );

final routineEngineWeightSuggestionProvider =
    FutureProvider.family<
      EngineWeightSuggestion?,
      RoutineLoadRecommendationParams
    >((ref, params) async {
      final recommendation = await ref.watch(
        routineLoadRecommendationProvider(params).future,
      );
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
    required this.currentAcwrSummary,
    required this.dailyLoadsCount,
    required this.lastTopSetsCount,
    required this.e1rmHistoryCount,
    required this.latestDailyLoad,
    required this.lastTopSetRows,
    required this.e1rmHistoryRows,
  });

  final String acwrSummary;
  final String currentAcwrSummary;
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
          : 'daily acute ${acwrState.acuteEwma.toStringAsFixed(1)} / '
                'chronic ${acwrState.chronicEwma.toStringAsFixed(1)} · '
                'ratio ${engine.currentAcwr()?.ratio.toStringAsFixed(2)} · '
                '${engine.currentAcwr()?.zone.name} · '
                '${acwrState.lastComputedDate.toLocal().toIso8601String()}';
      final currentAcwr = engine.currentAcwr(at: DateTime.now());
      final currentAcwrSummary = currentAcwr == null
          ? 'Unavailable'
          : 'ratio ${currentAcwr.ratio.toStringAsFixed(2)} · '
                '${currentAcwr.zone.name}';

      final dailyLoads = state.dailyLoads;
      final latestDailyLoad = dailyLoads.isEmpty
          ? null
          : EngineDebugDailyLoadSummary(
              date: dailyLoads.last.date.toIso8601String(),
              volume: dailyLoads.last.volumeLoad.toStringAsFixed(1),
            );

      String resolveName(String id) => engine.registry.lookup(id)?.name ?? id;

      final lastTopSetRows = state.lastTopSets.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final e1rmHistoryRows = state.e1rmHistory.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      return EngineDebugPersistedStateSummary(
        acwrSummary: acwrSummary,
        currentAcwrSummary: currentAcwrSummary,
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
        final name = engine.registry.lookup(entry.key)?.name ?? entry.key;
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
  if (set.hasTimedLoad && !set.hasStrengthLoad) {
    return '${set.durationSeconds}s @ ${set.rpe.toStringAsFixed(1)}';
  }
  return '${set.weightKg.toStringAsFixed(1)} kg × ${set.reps} @ ${set.rpe.toStringAsFixed(1)}';
}
