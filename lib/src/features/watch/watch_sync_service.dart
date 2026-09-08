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
import 'package:strength_training_tracker/src/l10n/exercise_translations.dart';

final watchSyncServiceProvider = Provider<WatchSyncService>((ref) {
  final service = WatchSyncService(ref);
  ref.onDispose(service.dispose);
  return service;
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
  int _generation = 0;
  bool _hasPublishedIdle = false;
  String? _idleLocale;
  ProviderSubscription<AppState>? _stateSubscription;

  // Active timed exercise timer state (set by active_workout_screen)
  String? _activeTimerExerciseId;
  DateTime? _activeTimerStartedAt;

  /// Start listening for state changes and Watch events.
  /// Call this once during app initialization.
  void initialize() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (_isListening) return;
    _isListening = true;
    _hasPublishedIdle = false;

    // Listen for Watch → Phone messages
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleWatchEvent,
      onError: (error) {
        debugPrint('Watch event stream error: $error');
      },
    );

    // Listen for state changes and push to Watch
    _stateSubscription = _ref.listen<AppState>(appStateControllerProvider, (
      previous,
      next,
    ) {
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
    _generation++;
    _stateSubscription?.close();
    _stateSubscription = null;
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

  Future<void> _onStateChanged(
    AppState state, {
    String? syncRequestId,
    bool force = false,
  }) async {
    final locale = _locale(state);
    final session = state.activeSession;
    if (session == null &&
        _hasPublishedIdle &&
        _idleLocale == locale &&
        !force) {
      return;
    }
    final generation = ++_generation;
    _pendingSyncRetry?.cancel();
    if (session == null) {
      final endedSessionId = _lastSentSessionId;
      _lastSentSessionId = null;
      _activeTimerExerciseId = null;
      _activeTimerStartedAt = null;
      _hasPublishedIdle = true;
      _idleLocale = locale;
      await _sendStateWithRetry(
        endedSessionId == null ? 'sendSessionIdle' : 'sendSessionEnd',
        {
          'sessionId': ?endedSessionId,
          'locale': locale,
          'syncRequestId': ?syncRequestId,
        },
        generation,
      );
      return;
    }

    _hasPublishedIdle = false;
    _lastSentSessionId = session.id;
    final routine = state.routineById(session.routineId);
    if (routine == null) return;
    final snapshot = await _buildSessionSnapshot(state, session, routine);
    if (syncRequestId != null) snapshot['syncRequestId'] = syncRequestId;
    await _sendStateWithRetry('sendSessionUpdate', snapshot, generation);
  }

  Future<Map<String, dynamic>> _buildSessionSnapshot(
    AppState state,
    WorkoutSession session,
    Routine routine,
  ) async {
    final locale = _locale(state);
    final unit = state.preferredUnit;

    final exercises = <Map<String, dynamic>>[];
    for (final re in routine.exercises) {
      if (!_isListening) return {};
      final exercise = state.exerciseById(re.exerciseId);
      final name = exercise != null
          ? _localizedExerciseName(exercise, locale)
          : 'Unknown';
      final suggestion = await _ref
          .read(
            routineEngineWeightSuggestionProvider(
              RoutineLoadRecommendationParams(
                exerciseId: re.exerciseId,
                targetReps: re.targetReps,
              ),
            ).future,
          )
          .catchError((Object error) {
            debugPrint('Watch weight recommendation unavailable: $error');
            return null;
          });
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

    final sessionData = <String, dynamic>{
      'sessionId': session.id,
      'routineId': session.routineId,
      'routineName': routine.name,
      'startedAt': session.startedAt.toUtc().toIso8601String(),
      'currentExerciseIndex': session.currentExerciseIndex,
      'exercises': exercises,
    };
    final activeRest = _buildActiveRest(state, session, routine, locale);
    if (activeRest != null) {
      sessionData['activeRest'] = activeRest;
    }

    return {
      'type': 'session_update',
      'session': sessionData,
      'locale': locale,
      'unit': unit,
    };
  }

  Map<String, dynamic>? _buildActiveRest(
    AppState state,
    WorkoutSession session,
    Routine routine,
    String locale,
  ) {
    if (session.completedSets.isEmpty) return null;

    final allSets = [...session.completedSets]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final lastSet = allSets.first;

    final prescription = routine.exercises
        .where((item) => item.exerciseId == lastSet.exerciseId)
        .firstOrNull;
    final restSeconds = prescription?.restSeconds ?? 0;
    if (restSeconds <= 0) return null;

    final endsAt = lastSet.completedAt.add(Duration(seconds: restSeconds));
    if (!endsAt.isAfter(DateTime.now())) return null;

    final exercise = state.exerciseById(lastSet.exerciseId);
    final exerciseName = exercise != null
        ? _localizedExerciseName(exercise, locale)
        : 'Unknown';

    return {
      'sourceExerciseId': lastSet.exerciseId,
      'sourceExerciseName': exerciseName,
      'startedAt': lastSet.completedAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'restSeconds': restSeconds,
    };
  }

  String _localizedExerciseName(Exercise exercise, String locale) {
    final language = locale.toLowerCase().startsWith('fr') ? 'fr' : 'en';
    return ExerciseTranslations.displayNameForLocalizations(
      lookupAppLocalizations(Locale(language)),
      exercise,
    );
  }

  String _locale(AppState state) {
    final raw = state.preferredLanguage.isNotEmpty
        ? state.preferredLanguage
        : PlatformDispatcher.instance.locale.languageCode;
    return raw.toLowerCase().startsWith('fr') ? 'fr' : 'en';
  }

  Future<void> _sendStateWithRetry(
    String method,
    Map<String, dynamic> payload,
    int generation, {
    int attempt = 0,
  }) async {
    if (!_isListening || generation != _generation) return;
    try {
      await _methodChannel.invokeMethod<void>(method, payload);
    } catch (error) {
      if (!_isListening || generation != _generation) return;
      if (attempt >= 7) {
        debugPrint('Watch channel unavailable after retries: $error');
        return;
      }
      _pendingSyncRetry?.cancel();
      _pendingSyncRetry = Timer(
        _initialSyncRetryDelay * (1 << attempt.clamp(0, 3)),
        () => unawaited(
          _sendStateWithRetry(
            method,
            payload,
            generation,
            attempt: attempt + 1,
          ),
        ),
      );
    }
  }

  // MARK: - Watch → State

  void _handleWatchEvent(dynamic event) {
    if (event is! Map) return;
    final data = Map<String, dynamic>.from(event);
    final type = data['type'] as String?;

    switch (type) {
      case 'request_sync':
        _handleSyncRequest(data['syncRequestId'] as String?);
      default:
        debugPrint('Unknown Watch event type: $type');
    }
  }

  void _handleSyncRequest(String? syncRequestId) {
    final state = _ref.read(appStateControllerProvider);
    unawaited(
      _onStateChanged(state, syncRequestId: syncRequestId, force: true),
    );
  }

  // MARK: - Query methods

  Future<bool> isWatchPaired() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('isWatchPaired');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isWatchReachable() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
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
