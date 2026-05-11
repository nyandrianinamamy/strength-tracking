import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const watchChannel = MethodChannel('com.strengthapp/watch');
  const liveActivityChannel = MethodChannel('com.strengthapp/live_activity');

  setUpAll(() {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError(
        'native_runtime_wiring_test must run on iOS so it exercises the real '
        'WatchConnectivity and Live Activity MethodChannel handlers.',
      );
    }
  });

  group('iOS native runtime channel wiring', () {
    testWidgets('Watch channel handlers accept active workout snapshots', (
      _,
    ) async {
      final paired = await watchChannel.invokeMethod<bool>('isWatchPaired');
      final reachable = await watchChannel.invokeMethod<bool>(
        'isWatchReachable',
      );

      expect(paired, isA<bool>());
      expect(reachable, isA<bool>());

      await watchChannel.invokeMethod<void>(
        'sendSessionUpdate',
        _watchSnapshot(
          sessionId: 'native-smoke-watch-suggested',
          suggestedWeightKg: 82.5,
        ),
      );
      await watchChannel.invokeMethod<void>(
        'sendSessionUpdate',
        _watchSnapshot(
          sessionId: 'native-smoke-watch-null-suggestion',
          suggestedWeightKg: null,
        ),
      );
      await watchChannel.invokeMethod<void>('sendSessionEnd');
    });

    testWidgets('Live Activity channel handlers accept workout lifecycle', (
      _,
    ) async {
      final now = DateTime.now().toUtc();
      final restEndAt = now.add(const Duration(milliseconds: 500));

      await liveActivityChannel.invokeMethod<void>('syncWorkout', {
        'sessionId': 'native-smoke-live-activity',
        'routineName': 'Native Smoke Push Day',
        'currentExerciseName': 'Incline Dumbbell Press',
        'currentExerciseType': 'strength',
        'currentExerciseIndex': 2,
        'totalExercises': 6,
        'completedSetsText': '3 total sets',
        'currentExerciseProgressText': '1/3 sets',
        'exerciseDetailText': '10 reps target',
        'startedAt': now
            .subtract(const Duration(minutes: 18))
            .toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'restEndAt': restEndAt.toIso8601String(),
        'restSeconds': 90,
        'lastSetAt': now
            .subtract(const Duration(seconds: 20))
            .toIso8601String(),
        'hasActiveRest': true,
      });

      await liveActivityChannel.invokeMethod<void>('endWorkout');
    });
  });
}

Map<String, Object?> _watchSnapshot({
  required String sessionId,
  required double? suggestedWeightKg,
}) {
  final now = DateTime.now().toUtc();

  return {
    'type': 'session_update',
    'session': {
      'sessionId': sessionId,
      'routineId': 'native-smoke-push-day',
      'routineName': 'Native Smoke Push Day',
      'startedAt': now.subtract(const Duration(minutes: 12)).toIso8601String(),
      'currentExerciseIndex': 0,
      'exercises': [
        {
          'exerciseId': 'barbell_bench_press',
          'name': 'Barbell Bench Press',
          'exerciseType': 'strength',
          'targetSets': 3,
          'targetReps': 8,
          'targetDurationSeconds': 0,
          'restSeconds': 90,
          'suggestedWeightKg': suggestedWeightKg,
          'completedSets': [
            {
              'setNumber': 1,
              'weightKg': 80.0,
              'reps': 8,
              'durationSeconds': 0,
              'completedAt': now
                  .subtract(const Duration(minutes: 4))
                  .toIso8601String(),
            },
          ],
        },
        {
          'exerciseId': 'plank',
          'name': 'Plank',
          'exerciseType': 'timed',
          'targetSets': 2,
          'targetReps': 0,
          'targetDurationSeconds': 45,
          'restSeconds': 60,
          'suggestedWeightKg': null,
          'activeTimerStartedAt': now
              .subtract(const Duration(seconds: 10))
              .toIso8601String(),
          'completedSets': const [],
        },
      ],
    },
    'locale': 'en',
    'unit': 'kg',
    'weightIncrement': 2.5,
  };
}
