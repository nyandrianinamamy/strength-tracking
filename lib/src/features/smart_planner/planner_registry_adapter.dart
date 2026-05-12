import 'package:training_engine/training_engine.dart';
import '../../data/models/exercise.dart';
import '../training_engine/training_engine_adapter.dart';

/// Builds an [ExerciseRegistry] populated with both default engine exercises
/// and user-defined exercises from the app state.
class PlannerRegistryAdapter {
  const PlannerRegistryAdapter._();

  static ExerciseRegistry buildRegistry(List<Exercise> appExercises) {
    final registry = ExerciseRegistry.withDefaults();
    const adapter = TrainingEngineAdapter();

    for (final exercise in appExercises) {
      if (exercise.archived) continue;
      final engineExercise = adapter.toEngineExercise(exercise, registry);
      if (engineExercise != null) {
        registry.addCustom(engineExercise);
      }
    }

    return registry;
  }

  static PlannerEngineContext buildEngineContext(TrainingEngine engine) {
    final fatigueMap = engine.fullFatigueMap().map(
      (muscle, status) => MapEntry(muscle, status.level),
    );
    final readiness = engine.computeReadiness();
    return PlannerEngineContext(
      fatigueByMuscle: fatigueMap,
      readinessScore: readiness.score,
      sessionsIngested: engine.state.sessionsIngested,
    );
  }
}
