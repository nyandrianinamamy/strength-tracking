import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';

final watchSyncServiceProvider = Provider<WatchSyncService>((ref) {
  return WatchSyncService(ref);
});

class WatchSyncService {
  WatchSyncService(this._ref);

  final Ref _ref;
  static const _initialSyncRetryDelay = Duration(milliseconds: 250);

  static const _methodChannel = MethodChannel('com.strengthapp/watch');
  static const _eventChannel = EventChannel('com.strengthapp/watch_events');

  StreamSubscription<dynamic>? _eventSubscription;
  bool _isListening = false;
  String? _lastSentSessionId;
  Timer? _pendingSyncRetry;
  Map<String, dynamic>? _pendingSnapshot;

  // Active timed exercise timer state (set by active_workout_screen)
  String? _activeTimerExerciseId;
  DateTime? _activeTimerStartedAt;

  /// Start listening for state changes and Watch events.
  /// Call this once during app initialization.
  void initialize() {
    if (kIsWeb) return;
    if (_isListening) return;
    _isListening = true;

    // Listen for Watch → Phone messages
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleWatchEvent,
      onError: (error) {
        debugPrint('Watch event stream error: $error');
      },
    );

    // Listen for state changes and push to Watch
    _ref.listen<AppState>(appStateControllerProvider, (previous, next) {
      unawaited(_onStateChanged(next));
    });

    // Send initial state if there's an active session
    final state = _ref.read(appStateControllerProvider);
    unawaited(_onStateChanged(state));
  }

  void dispose() {
    _eventSubscription?.cancel();
    _pendingSyncRetry?.cancel();
    _isListening = false;
  }

  /// Called by active_workout_screen when a timed exercise timer starts or stops.
  void updateTimedExerciseTimer({
    required String? exerciseId,
    required DateTime? startedAt,
  }) {
    _activeTimerExerciseId = exerciseId;
    _activeTimerStartedAt = startedAt;
    // Trigger immediate sync so Watch gets the timer state
    final state = _ref.read(appStateControllerProvider);
    unawaited(_onStateChanged(state));
  }

  // MARK: - State → Watch

  Future<void> _onStateChanged(AppState state) async {
    final session = state.activeSession;
    if (session == null) {
      _pendingSyncRetry?.cancel();
      _pendingSnapshot = null;
      // If we previously had a session, send session_end
      if (_lastSentSessionId != null) {
        _sendSessionEnd();
        _lastSentSessionId = null;
      }
      return;
    }

    _lastSentSessionId = session.id;

    final routine = state.routineById(session.routineId);
    if (routine == null) return;
    final snapshot = await _buildSessionSnapshot(state, session, routine);
    _sendSessionUpdateWithRetry(snapshot, session.id);
  }

  Future<Map<String, dynamic>> _buildSessionSnapshot(
    AppState state,
    WorkoutSession session,
    Routine routine,
  ) async {
    final locale = state.preferredLanguage.isNotEmpty
        ? state.preferredLanguage
        : 'en';
    final unit = state.preferredUnit;
    final weightIncrement = unit == 'lbs' ? 5.0 : 2.5;

    final exercises = <Map<String, dynamic>>[];
    for (final re in routine.exercises) {
      final exercise = state.exerciseById(re.exerciseId);
      final name = exercise != null
          ? _localizedExerciseName(exercise, locale)
          : 'Unknown';
      final suggestion = await _ref.read(
        engineWeightSuggestionProvider(re.exerciseId).future,
      );
      final completedSets =
          session.completedSets
              .where((s) => s.exerciseId == re.exerciseId)
              .toList()
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

      final completedSetData = completedSets.map((s) {
        return <String, dynamic>{
          'setNumber': s.setNumber,
          'weightKg': s.weightKg,
          'reps': s.reps,
          'durationSeconds': s.durationSeconds,
          'completedAt': s.completedAt.toUtc().toIso8601String(),
        };
      }).toList();

      final exerciseData = <String, dynamic>{
        'exerciseId': re.exerciseId,
        'name': name,
        'exerciseType': exercise?.exerciseType ?? 'strength',
        'targetSets': re.targetSets,
        'targetReps': re.targetReps,
        'targetDurationSeconds': re.targetDurationSeconds,
        'restSeconds': re.restSeconds,
        'completedSets': completedSetData,
      };
      if (suggestion?.suggestedWeightKg != null) {
        exerciseData['suggestedWeightKg'] = suggestion!.suggestedWeightKg;
      }

      // Add active timer state if this exercise has a running timer
      if (_activeTimerExerciseId == re.exerciseId &&
          _activeTimerStartedAt != null) {
        exerciseData['activeTimerStartedAt'] = _activeTimerStartedAt!
            .toUtc()
            .toIso8601String();
      }
      exercises.add(exerciseData);
    }

    return {
      'type': 'session_update',
      'session': {
        'sessionId': session.id,
        'routineId': session.routineId,
        'routineName': routine.name,
        'startedAt': session.startedAt.toUtc().toIso8601String(),
        'currentExerciseIndex': session.currentExerciseIndex,
        'exercises': exercises,
      },
      'locale': locale,
      'unit': unit,
      'weightIncrement': weightIncrement,
    };
  }

  String _localizedExerciseName(Exercise exercise, String locale) {
    if (exercise.translationKey != null &&
        exercise.translationKey!.isNotEmpty) {
      try {
        final l10n = lookupAppLocalizations(Locale(locale));
        final resolvers = <String, String Function(AppLocalizations)>{
          'exercise_barbell_bench_press': (l) => l.exercise_barbell_bench_press,
          'exercise_incline_barbell_press': (l) =>
              l.exercise_incline_barbell_press,
          'exercise_decline_barbell_press': (l) =>
              l.exercise_decline_barbell_press,
          'exercise_dumbbell_bench_press': (l) =>
              l.exercise_dumbbell_bench_press,
          'exercise_incline_dumbbell_press': (l) =>
              l.exercise_incline_dumbbell_press,
          'exercise_cable_fly': (l) => l.exercise_cable_fly,
          'exercise_pec_deck': (l) => l.exercise_pec_deck,
          'exercise_push_up': (l) => l.exercise_push_up,
          'exercise_barbell_row': (l) => l.exercise_barbell_row,
          'exercise_dumbbell_row': (l) => l.exercise_dumbbell_row,
          'exercise_lat_pulldown': (l) => l.exercise_lat_pulldown,
          'exercise_pull_up': (l) => l.exercise_pull_up,
          'exercise_chin_up': (l) => l.exercise_chin_up,
          'exercise_seated_cable_row': (l) => l.exercise_seated_cable_row,
          'exercise_t_bar_row': (l) => l.exercise_t_bar_row,
          'exercise_face_pull': (l) => l.exercise_face_pull,
          'exercise_overhead_press': (l) => l.exercise_overhead_press,
          'exercise_dumbbell_shoulder_press': (l) =>
              l.exercise_dumbbell_shoulder_press,
          'exercise_lateral_raise': (l) => l.exercise_lateral_raise,
          'exercise_front_raise': (l) => l.exercise_front_raise,
          'exercise_rear_delt_fly': (l) => l.exercise_rear_delt_fly,
          'exercise_arnold_press': (l) => l.exercise_arnold_press,
          'exercise_barbell_curl': (l) => l.exercise_barbell_curl,
          'exercise_dumbbell_curl': (l) => l.exercise_dumbbell_curl,
          'exercise_hammer_curl': (l) => l.exercise_hammer_curl,
          'exercise_preacher_curl': (l) => l.exercise_preacher_curl,
          'exercise_cable_curl': (l) => l.exercise_cable_curl,
          'exercise_tricep_pushdown': (l) => l.exercise_tricep_pushdown,
          'exercise_overhead_tricep_extension': (l) =>
              l.exercise_overhead_tricep_extension,
          'exercise_skull_crusher': (l) => l.exercise_skull_crusher,
          'exercise_dips': (l) => l.exercise_dips,
          'exercise_close_grip_bench_press': (l) =>
              l.exercise_close_grip_bench_press,
          'exercise_barbell_back_squat': (l) => l.exercise_barbell_back_squat,
          'exercise_front_squat': (l) => l.exercise_front_squat,
          'exercise_leg_press': (l) => l.exercise_leg_press,
          'exercise_leg_extension': (l) => l.exercise_leg_extension,
          'exercise_bulgarian_split_squat': (l) =>
              l.exercise_bulgarian_split_squat,
          'exercise_goblet_squat': (l) => l.exercise_goblet_squat,
          'exercise_hack_squat': (l) => l.exercise_hack_squat,
          'exercise_walking_lunge': (l) => l.exercise_walking_lunge,
          'exercise_romanian_deadlift': (l) => l.exercise_romanian_deadlift,
          'exercise_lying_leg_curl': (l) => l.exercise_lying_leg_curl,
          'exercise_seated_leg_curl': (l) => l.exercise_seated_leg_curl,
          'exercise_stiff_leg_deadlift': (l) => l.exercise_stiff_leg_deadlift,
          'exercise_good_morning': (l) => l.exercise_good_morning,
          'exercise_hip_thrust': (l) => l.exercise_hip_thrust,
          'exercise_glute_bridge': (l) => l.exercise_glute_bridge,
          'exercise_cable_kickback': (l) => l.exercise_cable_kickback,
          'exercise_step_up': (l) => l.exercise_step_up,
          'exercise_crunch': (l) => l.exercise_crunch,
          'exercise_hanging_leg_raise': (l) => l.exercise_hanging_leg_raise,
          'exercise_plank': (l) => l.exercise_plank,
          'exercise_cable_woodchop': (l) => l.exercise_cable_woodchop,
          'exercise_ab_wheel_rollout': (l) => l.exercise_ab_wheel_rollout,
          'exercise_conventional_deadlift': (l) =>
              l.exercise_conventional_deadlift,
          'exercise_sumo_deadlift': (l) => l.exercise_sumo_deadlift,
          'exercise_trap_bar_deadlift': (l) => l.exercise_trap_bar_deadlift,
          'exercise_treadmill': (l) => l.exercise_treadmill,
          'exercise_stationary_bike': (l) => l.exercise_stationary_bike,
          'exercise_rowing_machine': (l) => l.exercise_rowing_machine,
          'exercise_stair_climber': (l) => l.exercise_stair_climber,
          'exercise_elliptical': (l) => l.exercise_elliptical,
        };
        final resolver = resolvers[exercise.translationKey!];
        if (resolver != null) return resolver(l10n);
      } catch (_) {}
    }
    return exercise.name;
  }

  Future<void> _sendSessionUpdateWithRetry(
    Map<String, dynamic> snapshot,
    String sessionId,
  ) async {
    final success = await _sendSessionUpdate(snapshot);
    if (success) {
      _pendingSyncRetry?.cancel();
      _pendingSnapshot = null;
      return;
    }

    if (_lastSentSessionId != sessionId) return;
    _pendingSnapshot = snapshot;
    _pendingSyncRetry?.cancel();
    _pendingSyncRetry = Timer(_initialSyncRetryDelay, () {
      final pending = _pendingSnapshot;
      if (pending == null || _lastSentSessionId != sessionId) return;
      _sendSessionUpdateWithRetry(pending, sessionId);
    });
  }

  Future<bool> _sendSessionUpdate(Map<String, dynamic> snapshot) async {
    try {
      await _methodChannel.invokeMethod('sendSessionUpdate', snapshot);
      return true;
    } catch (e) {
      debugPrint('Failed to send session update to Watch: $e');
      return false;
    }
  }

  Future<void> _sendSessionEnd() async {
    try {
      _pendingSyncRetry?.cancel();
      _pendingSnapshot = null;
      await _methodChannel.invokeMethod('sendSessionEnd');
    } catch (e) {
      debugPrint('Failed to send session end to Watch: $e');
    }
  }

  // MARK: - Watch → State

  void _handleWatchEvent(dynamic event) {
    if (event is! Map) return;
    final data = Map<String, dynamic>.from(event);
    final type = data['type'] as String?;

    switch (type) {
      case 'log_set':
        _handleLogSet(data);
      case 'log_timed_set':
        _handleLogTimedSet(data);
      case 'request_sync':
        _handleSyncRequest();
      default:
        debugPrint('Unknown Watch event type: $type');
    }
  }

  void _handleLogSet(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as String?;
    final exerciseId = data['exerciseId'] as String?;
    final setNumber = data['setNumber'] as int?;
    final weightKg = (data['weightKg'] as num?)?.toDouble();
    final reps = data['reps'] as int?;

    if (sessionId == null ||
        exerciseId == null ||
        setNumber == null ||
        weightKg == null ||
        reps == null) {
      debugPrint('Invalid log_set data from Watch: $data');
      return;
    }

    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;
    if (session.id != sessionId) {
      debugPrint('Ignoring stale Watch log_set for session $sessionId');
      return;
    }

    // Duplicate detection
    final existingSet = session.completedSets.any(
      (s) => s.exerciseId == exerciseId && s.setNumber == setNumber,
    );
    if (existingSet) {
      debugPrint(
        'Duplicate set from Watch ignored: $exerciseId set $setNumber',
      );
      return;
    }

    // Navigate to the exercise if needed
    final routine = state.routineById(session.routineId);
    if (routine != null) {
      final exerciseIndex = routine.exercises.indexWhere(
        (e) => e.exerciseId == exerciseId,
      );
      if (exerciseIndex >= 0 && exerciseIndex != session.currentExerciseIndex) {
        _ref.read(workoutControllerProvider).goToExercise(exerciseIndex);
      }
    }

    _ref.read(workoutControllerProvider).logSet(weightKg: weightKg, reps: reps);
  }

  void _handleLogTimedSet(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as String?;
    final exerciseId = data['exerciseId'] as String?;
    final setNumber = data['setNumber'] as int?;
    final durationSeconds = data['durationSeconds'] as int?;

    if (sessionId == null ||
        exerciseId == null ||
        setNumber == null ||
        durationSeconds == null) {
      debugPrint('Invalid log_timed_set data from Watch: $data');
      return;
    }

    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;
    if (session.id != sessionId) {
      debugPrint('Ignoring stale Watch log_timed_set for session $sessionId');
      return;
    }

    // Duplicate detection
    final existingSet = session.completedSets.any(
      (s) => s.exerciseId == exerciseId && s.setNumber == setNumber,
    );
    if (existingSet) {
      debugPrint(
        'Duplicate timed set from Watch ignored: $exerciseId set $setNumber',
      );
      return;
    }

    // Navigate to the exercise if needed
    final routine = state.routineById(session.routineId);
    if (routine != null) {
      final exerciseIndex = routine.exercises.indexWhere(
        (e) => e.exerciseId == exerciseId,
      );
      if (exerciseIndex >= 0 && exerciseIndex != session.currentExerciseIndex) {
        _ref.read(workoutControllerProvider).goToExercise(exerciseIndex);
      }
    }

    _ref
        .read(workoutControllerProvider)
        .logTimedSet(durationSeconds: durationSeconds);
  }

  void _handleSyncRequest() {
    final state = _ref.read(appStateControllerProvider);
    _onStateChanged(state);
  }

  // MARK: - Query methods

  Future<bool> isWatchPaired() async {
    if (kIsWeb) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('isWatchPaired');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isWatchReachable() async {
    if (kIsWeb) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isWatchReachable',
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
