import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:training_engine/training_engine.dart';

// ---------------------------------------------------------------------------
// Core engine provider
// ---------------------------------------------------------------------------

/// Provides a singleton [TrainingEngine] instance.
///
/// The engine is initialised with default demographic data. In production,
/// this should be overridden (via `ProviderContainer.overrides` or
/// `ProviderScope.overrides`) once the user's profile is available from
/// onboarding.
final trainingEngineProvider = Provider<TrainingEngine>((ref) {
  final registry = ExerciseRegistry.withDefaults();
  final profile = UserProfile(
    sex: Sex.male,
    age: 25,
    bodyWeightKg: 75.0,
    experience: ExperienceLevel.intermediate,
    goal: HypertrophyGoal.hypertrophy,
    availableDays: [1, 3, 5], // Mon, Wed, Fri
    maxSessionDuration: const Duration(minutes: 60),
    createdAt: DateTime.now(),
  );
  return TrainingEngine(registry: registry, profile: profile);
});

// ---------------------------------------------------------------------------
// Derived providers
// ---------------------------------------------------------------------------

/// Returns the current per-muscle fatigue map.
final fatigueMapProvider = Provider<Map<String, FatigueStatus>>((ref) {
  return ref.watch(trainingEngineProvider).fullFatigueMap();
});

/// Returns the current composite readiness score.
final readinessProvider = Provider<ReadinessScore>((ref) {
  return ref.watch(trainingEngineProvider).computeReadiness();
});

/// Returns a [LoadRecommendation] for the given exercise ID, or `null` when
/// no e1RM data is available (engine falls back to baseline, so this will
/// always return a recommendation in practice, but guards against edge cases).
final loadRecommendationProvider =
    Provider.family<LoadRecommendation?, String>((ref, exerciseId) {
  final engine = ref.watch(trainingEngineProvider);
  // currentE1rm always returns a value (falls back to baseline), so this
  // check is a safety guard for truly degenerate states.
  if (engine.currentE1rm(exerciseId) == null) return null;
  return engine.recommendLoad(exerciseId);
});
