import 'package:flutter/widgets.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';

/// Resolves the display name of an exercise using the localized string
/// if a [translationKey] is present, otherwise falls back to [Exercise.name].
class ExerciseTranslations {
  ExerciseTranslations._();

  static String displayName(BuildContext context, Exercise exercise) {
    if (exercise.translationKey != null) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        final resolved = _resolveKey(l10n, exercise.translationKey!);
        if (resolved != null) return resolved;
      }
    }
    return exercise.name;
  }

  static String? _resolveKey(AppLocalizations l10n, String key) {
    return _resolvers[key]?.call(l10n);
  }

  static const _resolvers = <String, String Function(AppLocalizations)>{
    // Chest
    'exercise_barbell_bench_press': _bbBenchPress,
    'exercise_incline_barbell_press': _incBbPress,
    'exercise_decline_barbell_press': _decBbPress,
    'exercise_dumbbell_bench_press': _dbBenchPress,
    'exercise_incline_dumbbell_press': _incDbPress,
    'exercise_cable_fly': _cableFly,
    'exercise_pec_deck': _pecDeck,
    'exercise_push_up': _pushUp,
    // Back
    'exercise_barbell_row': _bbRow,
    'exercise_dumbbell_row': _dbRow,
    'exercise_lat_pulldown': _latPulldown,
    'exercise_pull_up': _pullUp,
    'exercise_chin_up': _chinUp,
    'exercise_seated_cable_row': _seatedCableRow,
    'exercise_t_bar_row': _tBarRow,
    'exercise_face_pull': _facePull,
    // Shoulders
    'exercise_overhead_press': _ohp,
    'exercise_dumbbell_shoulder_press': _dbShoulderPress,
    'exercise_lateral_raise': _latRaise,
    'exercise_front_raise': _frontRaise,
    'exercise_rear_delt_fly': _rearDeltFly,
    'exercise_arnold_press': _arnoldPress,
    // Biceps
    'exercise_barbell_curl': _bbCurl,
    'exercise_dumbbell_curl': _dbCurl,
    'exercise_hammer_curl': _hammerCurl,
    'exercise_preacher_curl': _preacherCurl,
    'exercise_cable_curl': _cableCurl,
    // Triceps
    'exercise_tricep_pushdown': _tricepPushdown,
    'exercise_overhead_tricep_extension': _ohTricepExt,
    'exercise_skull_crusher': _skullCrusher,
    'exercise_dips': _dips,
    'exercise_close_grip_bench_press': _cgBenchPress,
    // Quads
    'exercise_barbell_back_squat': _bbBackSquat,
    'exercise_front_squat': _frontSquat,
    'exercise_leg_press': _legPress,
    'exercise_leg_extension': _legExtension,
    'exercise_bulgarian_split_squat': _bulgarianSplitSquat,
    'exercise_goblet_squat': _gobletSquat,
    'exercise_hack_squat': _hackSquat,
    'exercise_walking_lunge': _walkingLunge,
    // Hamstrings
    'exercise_romanian_deadlift': _romanianDl,
    'exercise_lying_leg_curl': _lyingLegCurl,
    'exercise_seated_leg_curl': _seatedLegCurl,
    'exercise_stiff_leg_deadlift': _stiffLegDl,
    'exercise_good_morning': _goodMorning,
    // Glutes
    'exercise_hip_thrust': _hipThrust,
    'exercise_glute_bridge': _gluteBridge,
    'exercise_cable_kickback': _cableKickback,
    'exercise_step_up': _stepUp,
    // Abs
    'exercise_crunch': _crunch,
    'exercise_hanging_leg_raise': _hangingLegRaise,
    'exercise_plank': _plank,
    'exercise_cable_woodchop': _cableWoodchop,
    'exercise_ab_wheel_rollout': _abWheelRollout,
    // Compound / Deadlifts
    'exercise_conventional_deadlift': _conventionalDl,
    'exercise_sumo_deadlift': _sumoDl,
    'exercise_trap_bar_deadlift': _trapBarDl,
    // Cardio
    'exercise_treadmill': _treadmill,
    'exercise_stationary_bike': _stationaryBike,
    'exercise_rowing_machine': _rowingMachine,
    'exercise_stair_climber': _stairClimber,
    'exercise_elliptical': _elliptical,
  };

  // Chest
  static String _bbBenchPress(AppLocalizations l) => l.exercise_barbell_bench_press;
  static String _incBbPress(AppLocalizations l) => l.exercise_incline_barbell_press;
  static String _decBbPress(AppLocalizations l) => l.exercise_decline_barbell_press;
  static String _dbBenchPress(AppLocalizations l) => l.exercise_dumbbell_bench_press;
  static String _incDbPress(AppLocalizations l) => l.exercise_incline_dumbbell_press;
  static String _cableFly(AppLocalizations l) => l.exercise_cable_fly;
  static String _pecDeck(AppLocalizations l) => l.exercise_pec_deck;
  static String _pushUp(AppLocalizations l) => l.exercise_push_up;
  // Back
  static String _bbRow(AppLocalizations l) => l.exercise_barbell_row;
  static String _dbRow(AppLocalizations l) => l.exercise_dumbbell_row;
  static String _latPulldown(AppLocalizations l) => l.exercise_lat_pulldown;
  static String _pullUp(AppLocalizations l) => l.exercise_pull_up;
  static String _chinUp(AppLocalizations l) => l.exercise_chin_up;
  static String _seatedCableRow(AppLocalizations l) => l.exercise_seated_cable_row;
  static String _tBarRow(AppLocalizations l) => l.exercise_t_bar_row;
  static String _facePull(AppLocalizations l) => l.exercise_face_pull;
  // Shoulders
  static String _ohp(AppLocalizations l) => l.exercise_overhead_press;
  static String _dbShoulderPress(AppLocalizations l) => l.exercise_dumbbell_shoulder_press;
  static String _latRaise(AppLocalizations l) => l.exercise_lateral_raise;
  static String _frontRaise(AppLocalizations l) => l.exercise_front_raise;
  static String _rearDeltFly(AppLocalizations l) => l.exercise_rear_delt_fly;
  static String _arnoldPress(AppLocalizations l) => l.exercise_arnold_press;
  // Biceps
  static String _bbCurl(AppLocalizations l) => l.exercise_barbell_curl;
  static String _dbCurl(AppLocalizations l) => l.exercise_dumbbell_curl;
  static String _hammerCurl(AppLocalizations l) => l.exercise_hammer_curl;
  static String _preacherCurl(AppLocalizations l) => l.exercise_preacher_curl;
  static String _cableCurl(AppLocalizations l) => l.exercise_cable_curl;
  // Triceps
  static String _tricepPushdown(AppLocalizations l) => l.exercise_tricep_pushdown;
  static String _ohTricepExt(AppLocalizations l) => l.exercise_overhead_tricep_extension;
  static String _skullCrusher(AppLocalizations l) => l.exercise_skull_crusher;
  static String _dips(AppLocalizations l) => l.exercise_dips;
  static String _cgBenchPress(AppLocalizations l) => l.exercise_close_grip_bench_press;
  // Quads
  static String _bbBackSquat(AppLocalizations l) => l.exercise_barbell_back_squat;
  static String _frontSquat(AppLocalizations l) => l.exercise_front_squat;
  static String _legPress(AppLocalizations l) => l.exercise_leg_press;
  static String _legExtension(AppLocalizations l) => l.exercise_leg_extension;
  static String _bulgarianSplitSquat(AppLocalizations l) => l.exercise_bulgarian_split_squat;
  static String _gobletSquat(AppLocalizations l) => l.exercise_goblet_squat;
  static String _hackSquat(AppLocalizations l) => l.exercise_hack_squat;
  static String _walkingLunge(AppLocalizations l) => l.exercise_walking_lunge;
  // Hamstrings
  static String _romanianDl(AppLocalizations l) => l.exercise_romanian_deadlift;
  static String _lyingLegCurl(AppLocalizations l) => l.exercise_lying_leg_curl;
  static String _seatedLegCurl(AppLocalizations l) => l.exercise_seated_leg_curl;
  static String _stiffLegDl(AppLocalizations l) => l.exercise_stiff_leg_deadlift;
  static String _goodMorning(AppLocalizations l) => l.exercise_good_morning;
  // Glutes
  static String _hipThrust(AppLocalizations l) => l.exercise_hip_thrust;
  static String _gluteBridge(AppLocalizations l) => l.exercise_glute_bridge;
  static String _cableKickback(AppLocalizations l) => l.exercise_cable_kickback;
  static String _stepUp(AppLocalizations l) => l.exercise_step_up;
  // Abs
  static String _crunch(AppLocalizations l) => l.exercise_crunch;
  static String _hangingLegRaise(AppLocalizations l) => l.exercise_hanging_leg_raise;
  static String _plank(AppLocalizations l) => l.exercise_plank;
  static String _cableWoodchop(AppLocalizations l) => l.exercise_cable_woodchop;
  static String _abWheelRollout(AppLocalizations l) => l.exercise_ab_wheel_rollout;
  // Compound / Deadlifts
  static String _conventionalDl(AppLocalizations l) => l.exercise_conventional_deadlift;
  static String _sumoDl(AppLocalizations l) => l.exercise_sumo_deadlift;
  static String _trapBarDl(AppLocalizations l) => l.exercise_trap_bar_deadlift;
  // Cardio
  static String _treadmill(AppLocalizations l) => l.exercise_treadmill;
  static String _stationaryBike(AppLocalizations l) => l.exercise_stationary_bike;
  static String _rowingMachine(AppLocalizations l) => l.exercise_rowing_machine;
  static String _stairClimber(AppLocalizations l) => l.exercise_stair_climber;
  static String _elliptical(AppLocalizations l) => l.exercise_elliptical;
}
