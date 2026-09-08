import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/main.dart' as application;
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';

import 'ios_app_helpers.dart';
import 'ios_auth_helpers.dart';
import 'ios_fixtures.dart';

const _watchChannel = MethodChannel('com.strengthapp/watch');
const _activityChannel = MethodChannel('com.strengthapp/live_activity');

/// Exercises the real iOS -> WatchConnectivity -> watchOS decode/cache path.
/// The host driver reads the Watch cache and checks the actual visible Watch UI.
/// It never inserts received snapshots or writes Health authorization data.
void main() {
  final binding = _PairedWatchBinding();
  WidgetController.hitTestWarningShouldBeFatal = true;
  SharedPreferences.setPrefix('kotrana_paired_watch_e2e.');

  testWidgets(
    'paired Watch receives updates and preserves a new session',
    (tester) async {
      const simulatorId = String.fromEnvironment('E2E_PHONE_SIMULATOR_UDID');
      expect(Platform.isIOS, isTrue, reason: 'This test requires iOS.');
      expect(
        const bool.fromEnvironment('E2E_DISPOSABLE_SIMULATOR'),
        isTrue,
        reason: 'Run with tool/ci/run_ios_e2e.sh --paired-watch.',
      );
      expect(
        simulatorId,
        isNotEmpty,
        reason: 'Declare the runner simulator ID.',
      );
      // The plugin checks TARGET_OS_SIMULATOR in native code. A Dart define
      // alone is not accepted as proof that the app is on a simulator.
      final device = await const MethodChannel(
        'dev.fluttercommunity.plus/device_info',
      ).invokeMapMethod<String, dynamic>('getDeviceInfo');
      expect(
        device?['isPhysicalDevice'],
        isFalse,
        reason: 'Physical devices are not allowed by this test entrypoint.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Paired Watch transport acceptance')),
          ),
        ),
      );
      await tester.pump();

      await binding.checkpoint('prepare', {
        'mode': 'prepare',
        'phoneSimulatorId': simulatorId,
        'isPhysicalDevice': device?['isPhysicalDevice'],
      });

      final readyDeadline = DateTime.now().add(const Duration(seconds: 30));
      var retryAt = DateTime.now().add(const Duration(seconds: 5));
      var launchRetries = 0;
      var paired = false;
      var reachable = false;
      do {
        paired =
            await _watchChannel.invokeMethod<bool>('isWatchPaired') ?? false;
        reachable =
            await _watchChannel.invokeMethod<bool>('isWatchReachable') ?? false;
        if (paired && reachable) break;
        if (!reachable &&
            launchRetries < 2 &&
            DateTime.now().isAfter(retryAt)) {
          // A freshly installed Watch can activate before wcd has indexed its
          // companion metadata. Retry that process only; require real reachability.
          launchRetries++;
          await binding.checkpoint('watch-activation-retry-$launchRetries', {
            'mode': 'relaunch',
          });
          retryAt = DateTime.now().add(const Duration(seconds: 5));
        }
        await tester.pump(const Duration(milliseconds: 500));
      } while (DateTime.now().isBefore(readyDeadline));
      expect(paired, isTrue, reason: 'The native WCSession must be paired.');
      expect(
        reachable,
        isTrue,
        reason: 'The actual Watch app must be reachable.',
      );

      addTearDown(() => _watchChannel.invokeMethod<void>('sendSessionEnd'));
      final runId = DateTime.now().microsecondsSinceEpoch;
      final sessionA = 'paired-watch-$runId-a';
      final sessionB = 'paired-watch-$runId-b';

      await _watchChannel.invokeMethod<void>(
        'sendSessionUpdate',
        _snapshot(sessionA, exerciseIndex: 0, completedSets: 0),
      );
      await binding.checkpoint('session-a-start', {
        'mode': 'snapshot',
        'expected': _expected(sessionA, exerciseIndex: 0, completedSets: 0),
        'expectedVisibleText': 'Test strength exercise',
      });

      await _watchChannel.invokeMethod<void>(
        'sendSessionUpdate',
        _snapshot(sessionA, exerciseIndex: 1, completedSets: 1),
      );
      await binding.checkpoint('session-a-next-exercise', {
        'mode': 'snapshot',
        'expected': _expected(sessionA, exerciseIndex: 1, completedSets: 1),
        'expectedVisibleText': 'Test timed exercise',
      });

      // No wait between messages: an old end must not erase the next session.
      await _watchChannel.invokeMethod<void>('sendSessionEnd');
      await _watchChannel.invokeMethod<void>(
        'sendSessionUpdate',
        _snapshot(sessionB, exerciseIndex: 0, completedSets: 0),
      );
      await binding.checkpoint('session-b-survives-prior-end', {
        'mode': 'snapshot',
        'expected': _expected(sessionB, exerciseIndex: 0, completedSets: 0),
        'expectedVisibleText': 'Test strength exercise',
        'stableForSeconds': 5,
      });

      await _watchChannel.invokeMethod<void>('sendSessionEnd');
      await binding.checkpoint('session-b-ended', {
        'mode': 'idle',
        'stableForSeconds': 1,
        'expectedVisibleText': 'Aucune séance active',
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  testWidgets(
    'real app UI saves a workout through Watch and Live Activity services',
    (tester) async {
      const simulatorId = String.fromEnvironment('E2E_PHONE_SIMULATOR_UDID');
      expect(Platform.isIOS, isTrue);
      expect(const bool.fromEnvironment('E2E_DISPOSABLE_SIMULATOR'), isTrue);
      expect(simulatorId, isNotEmpty);
      final device = await const MethodChannel(
        'dev.fluttercommunity.plus/device_info',
      ).invokeMapMethod<String, dynamic>('getDeviceInfo');
      expect(device?['isPhysicalDevice'], isFalse);

      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      final fixture = e2eRichState(
        userName: 'Paired App Athlete',
        includeCompletedSessions: false,
      );
      // This case covers the UI/service/receiver/save chain. Notification
      // permission and timed-rest behavior have separate native acceptance.
      final seeded = fixture.copyWith(
        preferredLanguage: 'en',
        healthKitEnabled: false,
        routines: fixture.routines
            .map(
              (routine) => routine.copyWith(
                exercises: routine.exercises
                    .map((exercise) => exercise.copyWith(restSeconds: 0))
                    .toList(),
              ),
            )
            .toList(),
      );
      await AccountAppStateRepository(
        preferences: preferences,
        accountId: null,
      ).save(seeded);

      ProviderContainer? container;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container?.dispose();
        await uiFrames(tester);
        // Cleanup runs after all assertions, including if a checkpoint fails.
        await _watchChannel.invokeMethod<void>('sendSessionEnd');
        await _activityChannel.invokeMethod<void>('endWorkout');
      });
      container = await application.launchKotranaApp(
        firebaseOptions: inviteTestOptions,
        firebaseInitializer: () async {
          throw StateError('Injected Firebase failure for guest acceptance');
        },
      );
      await waitForUi(tester, find.text('Paired App Athlete'));
      expect(container.read(authServiceProvider).isAvailable, isFalse);
      final repository =
          container.read(appStateControllerProvider.notifier).repository
              as AccountAppStateRepository;
      expect(repository.accountId, isNull);
      expect(repository.remote, isNull);
      expect(container.read(appStateControllerProvider).activeSession, isNull);
      await _expectActivity(tester, sessionId: null);

      await binding.checkpoint('app-prepare', {
        'mode': 'prepare',
        'phoneSimulatorId': simulatorId,
        'isPhysicalDevice': device?['isPhysicalDevice'],
      });
      await _waitForAppWatch(tester, binding);

      await tapUi(tester, find.text('START SESSION'));
      await waitForUi(tester, find.text('FINISH'));
      final session = container.read(appStateControllerProvider).activeSession;
      expect(session, isNotNull);
      final sessionId = session!.id;
      expect(session.routineId, 'e2e_push_routine');
      expect(session.completedSets, isEmpty);
      await _expectActivity(tester, sessionId: sessionId, completedSets: 0);
      await binding.checkpoint('app-workout-started', {
        'mode': 'snapshot',
        'expected': _appExpected(sessionId, completedSets: 0),
        'expectedVisibleText': 'Flow Bench Press',
      });

      await logStrengthUi(tester, '80', '6');
      final logged = container
          .read(appStateControllerProvider)
          .activeSession!
          .completedSets
          .single;
      expect(logged.exerciseId, 'e2e_strength_press');
      expect(logged.weightKg, 80);
      expect(logged.reps, 6);
      expect(logged.rpe, 8);
      await _expectActivity(tester, sessionId: sessionId, completedSets: 1);
      await binding.checkpoint('app-strength-set-logged', {
        'mode': 'snapshot',
        'expected': _appExpected(sessionId, completedSets: 1),
        'expectedVisibleText': '80 kg x 6',
      });

      await finishUi(tester);
      expect(container.read(appStateControllerProvider).activeSession, isNull);
      await _expectActivity(tester, sessionId: null);
      await binding.checkpoint('app-workout-finished', {
        'mode': 'idle',
        'stableForSeconds': 1,
        'expectedVisibleText': 'No active workout',
      });
      final saved = await _readSavedWorkout(
        tester,
        preferences,
        repository.storageKey,
        sessionId,
      );
      expect(saved.userName, 'Paired App Athlete');
      expect(saved.activeSession, isNull);
      final completed = saved.completedSessions.single;
      expect(completed.id, sessionId);
      expect(completed.routineId, 'e2e_push_routine');
      expect(completed.endedAt, isNotNull);
      expect(completed.completedSets.single.exerciseId, 'e2e_strength_press');
      expect(completed.completedSets.single.weightKg, 80);
      expect(completed.completedSets.single.reps, 6);
      expect(completed.completedSets.single.rpe, 8);
      binding.reportData ??= {};
      binding.reportData!['appUiNativeChain'] = {
        'sessionId': sessionId,
        'savedCompletedSets': completed.completedSets.length,
        'weightKg': completed.completedSets.single.weightKg,
        'reps': completed.completedSets.single.reps,
        'firebaseFailure': 'injected',
        'repository': 'durable guest',
        'activityRemoved': true,
      };
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Map<String, Object?> _appExpected(
  String sessionId, {
  required int completedSets,
}) => {
  'sessionId': sessionId,
  'currentExerciseIndex': 0,
  'exerciseCount': 2,
  'firstExerciseCompletedSets': completedSets,
  'locale': 'en',
  'unit': 'kg',
};

Future<void> _waitForAppWatch(
  WidgetTester tester,
  _PairedWatchBinding binding,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  var retryAt = DateTime.now().add(const Duration(seconds: 5));
  var retries = 0;
  do {
    final paired = await _watchChannel.invokeMethod<bool>('isWatchPaired');
    final reachable = await _watchChannel.invokeMethod<bool>(
      'isWatchReachable',
    );
    if (paired == true && reachable == true) return;
    if (reachable != true && retries < 2 && DateTime.now().isAfter(retryAt)) {
      retries++;
      await binding.checkpoint('app-watch-activation-retry-$retries', {
        'mode': 'relaunch',
      });
      retryAt = DateTime.now().add(const Duration(seconds: 5));
    }
    await tester.pump(const Duration(milliseconds: 500));
  } while (DateTime.now().isBefore(deadline));
  fail('The real app requires a paired, reachable Watch before UI actions.');
}

Future<void> _expectActivity(
  WidgetTester tester, {
  required String? sessionId,
  int? completedSets,
}) async {
  assert(sessionId == null || completedSets != null);
  Map<String, dynamic>? observed;
  for (var attempt = 0; attempt < 100; attempt++) {
    observed = await _activityChannel.invokeMapMethod<String, dynamic>(
      'getWorkoutState',
    );
    expect(
      observed,
      isNotNull,
      reason: 'The native debug observer must reply.',
    );
    final activities = observed!['activities'] as List<dynamic>;
    if (sessionId == null) {
      if (activities.isEmpty &&
          (observed['pendingRestNotifications'] as List<dynamic>).isEmpty) {
        return;
      }
    } else if (activities.length == 1) {
      final activity = activities.single as Map<dynamic, dynamic>;
      if (activity['sessionId'] == sessionId &&
          activity['currentExerciseName'] == 'Flow Bench Press' &&
          activity['currentExerciseIndex'] == 1 &&
          activity['locale'] == 'en' &&
          activity['completedSetsText'] == '$completedSets total sets' &&
          activity['currentExerciseProgressText'] == '$completedSets/3 sets') {
        return;
      }
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Native ActivityKit state did not match session $sessionId: $observed');
}

Future<AppState> _readSavedWorkout(
  WidgetTester tester,
  SharedPreferences preferences,
  String storageKey,
  String sessionId,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await preferences.reload();
    final raw = preferences.getString(storageKey);
    if (raw != null) {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final saved = AppState.fromJson(
        envelope['state'] as Map<String, dynamic>,
      );
      if (saved.sessions.any(
        (session) =>
            session.id == sessionId &&
            session.status == WorkoutSessionStatus.completed,
      )) {
        return saved;
      }
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw TestFailure('The completed UI workout was not saved to local storage.');
}

Map<String, Object?> _expected(
  String sessionId, {
  required int exerciseIndex,
  required int completedSets,
}) => {
  'sessionId': sessionId,
  'currentExerciseIndex': exerciseIndex,
  'exerciseCount': 2,
  'firstExerciseCompletedSets': completedSets,
  'locale': 'fr',
  'unit': 'lbs',
};

Map<String, Object?> _snapshot(
  String sessionId, {
  required int exerciseIndex,
  required int completedSets,
}) {
  final now = DateTime.now().toUtc();
  return {
    'type': 'session_update',
    'locale': 'fr',
    'unit': 'lbs',
    'session': {
      'sessionId': sessionId,
      'routineId': 'paired-watch-routine',
      'routineName': 'Paired Watch acceptance',
      'startedAt': now.subtract(const Duration(minutes: 2)).toIso8601String(),
      'currentExerciseIndex': exerciseIndex,
      'exercises': [
        {
          'exerciseId': 'paired-watch-strength',
          'name': 'Test strength exercise',
          'exerciseType': 'strength',
          'targetSets': 3,
          'targetReps': 8,
          'restSeconds': 60,
          'suggestedWeightKg': 20.0,
          'completedSets': [
            if (completedSets > 0)
              {
                'setNumber': 1,
                'weightKg': 20.0,
                'reps': 8,
                'completedAt': now.toIso8601String(),
              },
          ],
        },
        {
          'exerciseId': 'paired-watch-timed',
          'name': 'Test timed exercise',
          'exerciseType': 'timed',
          'targetSets': 2,
          'targetReps': 0,
          'targetDurationSeconds': 45,
          'restSeconds': 30,
          'completedSets': <Object>[],
          if (exerciseIndex == 1) 'activeTimerStartedAt': now.toIso8601String(),
        },
      ],
    },
  };
}

/// iOS's stock screenshot callback cannot exchange in-test host commands.
/// This test-only protocol pauses each phase for host receipt/UI checks and
/// actual permission-sheet interactions when a known Health prompt appears.
class _PairedWatchBinding extends IntegrationTestWidgetsFlutterBinding {
  Completer<Map<String, Object?>> _next = Completer();
  Completer<Map<String, dynamic>>? _acknowledgment;
  String? _pendingName;

  Future<void> checkpoint(String name, Map<String, Object?> request) async {
    if (_acknowledgment != null) {
      throw StateError('A Watch checkpoint is already waiting.');
    }
    _pendingName = name;
    final acknowledgment = Completer<Map<String, dynamic>>();
    _acknowledgment = acknowledgment;
    _next.complete({'name': name, ...request});
    try {
      final result = await acknowledgment.future.timeout(
        const Duration(seconds: 120),
      );
      reportData ??= {};
      final checkpoints =
          reportData!.putIfAbsent('watchCheckpoints', () => <Object?>[])
              as List<Object?>;
      checkpoints.add({'name': name, ...result});
      expect(result['ok'], isTrue, reason: result['detail'] as String?);
    } finally {
      _acknowledgment = null;
      _pendingName = null;
    }
  }

  @override
  Future<Map<String, dynamic>> callback(Map<String, String> params) async {
    final message = params['message'];
    if (params['command'] != 'request_data' ||
        message == null ||
        !message.startsWith('paired-watch:')) {
      return super.callback(params);
    }

    Map<String, Object?> reply;
    if (message == 'paired-watch:next') {
      reply = await Future.any([
        _next.future,
        allTestsPassed.future.then((_) => {'finished': true}),
      ]);
      if (reply['finished'] != true) _next = Completer();
    } else if (message.startsWith('paired-watch:ack:')) {
      final acknowledgment =
          jsonDecode(message.substring('paired-watch:ack:'.length))
              as Map<String, dynamic>;
      final pending = _acknowledgment;
      if (pending == null ||
          pending.isCompleted ||
          acknowledgment['name'] != _pendingName) {
        throw StateError('Unexpected Watch checkpoint acknowledgment.');
      }
      pending.complete(acknowledgment);
      reply = {'accepted': true};
    } else {
      throw StateError('Unsupported paired Watch driver command.');
    }
    return {
      'isError': false,
      'response': {'message': jsonEncode(reply)},
    };
  }
}
