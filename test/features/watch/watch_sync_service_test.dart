import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/watch/watch_sync_service.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.strengthapp/watch');
  const eventChannel = EventChannel('com.strengthapp/watch_events');

  ProviderContainer buildContainer({AppState? initialState}) {
    final repository = MemoryAppStateRepository(
      initialState: initialState ?? DemoSeedData.initialState(),
    );

    return ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
      ],
    );
  }

  WorkoutSession buildActiveSession(String routineId) {
    return WorkoutSession(
      id: 'session_active',
      routineId: routineId,
      status: WorkoutSessionStatus.active,
      startedAt: DateTime(2026, 3, 21, 9),
      endedAt: null,
      currentExerciseIndex: 0,
      completedSets: const [],
      sessionNote: '',
      rpe: null,
    );
  }

  Future<void> pumpEvents() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('WatchSyncService', () {
    late TestDefaultBinaryMessenger messenger;
    late List<MethodCall> methodCalls;
    MockStreamHandlerEventSink? watchEvents;
    var failNextUpdate = false;

    setUp(() {
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      methodCalls = <MethodCall>[];
      watchEvents = null;
      failNextUpdate = false;

      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        methodCalls.add(call);
        if (call.method == 'sendSessionUpdate' && failNextUpdate) {
          failNextUpdate = false;
          throw PlatformException(code: 'channel-unavailable');
        }
        switch (call.method) {
          case 'isWatchPaired':
          case 'isWatchReachable':
            return false;
          default:
            return null;
        }
      });

      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (_, events) {
            watchEvents = events;
          },
          onCancel: (_) {
            watchEvents = null;
          },
        ),
      );
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(methodChannel, null);
      messenger.setMockStreamHandler(eventChannel, null);
    });

    test(
      'initializing with an active session sends a watch snapshot',
      () async {
        final seededState = DemoSeedData.initialState().copyWith(
          sessions: [buildActiveSession('push_day')],
        );
        final container = buildContainer(initialState: seededState);
        addTearDown(container.dispose);

        container.read(watchSyncServiceProvider).initialize();
        await pumpEvents();

        expect(methodCalls, hasLength(1));
        expect(methodCalls.single.method, 'sendSessionUpdate');

        final arguments = methodCalls.single.arguments as Map<dynamic, dynamic>;
        expect(arguments['type'], 'session_update');

        final session = arguments['session'] as Map<dynamic, dynamic>;
        expect(session['sessionId'], 'session_active');
        expect(session['routineId'], 'push_day');
        expect(session['currentExerciseIndex'], 0);

        final exercises = session['exercises'] as List<dynamic>;
        expect(exercises, hasLength(6));
        expect(
          (exercises.first as Map<dynamic, dynamic>)['exerciseId'],
          'barbell_bench_press',
        );
      },
    );

    test('initial sync retries when the first send fails', () async {
      final seededState = DemoSeedData.initialState().copyWith(
        sessions: [buildActiveSession('push_day')],
      );
      final container = buildContainer(initialState: seededState);
      addTearDown(container.dispose);

      failNextUpdate = true;
      container.read(watchSyncServiceProvider).initialize();
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(
        methodCalls.where((call) => call.method == 'sendSessionUpdate'),
        hasLength(2),
      );
    });

    test('starting and completing a session sends update then end', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final service = container.read(watchSyncServiceProvider);
      service.initialize();
      await pumpEvents();
      methodCalls.clear();

      container.read(routineControllerProvider).startSession('pull_day');
      await pumpEvents();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'sendSessionUpdate');

      methodCalls.clear();
      container.read(workoutControllerProvider).completeSession(rpe: 8);
      await pumpEvents();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'sendSessionEnd');
    });

    test('request_sync event resends the latest session snapshot', () async {
      final seededState = DemoSeedData.initialState().copyWith(
        sessions: [buildActiveSession('full_body')],
      );
      final container = buildContainer(initialState: seededState);
      addTearDown(container.dispose);

      container.read(watchSyncServiceProvider).initialize();
      await pumpEvents();
      methodCalls.clear();

      watchEvents!.success(<String, Object?>{'type': 'request_sync'});
      await pumpEvents();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'sendSessionUpdate');

      final arguments = methodCalls.single.arguments as Map<dynamic, dynamic>;
      final session = arguments['session'] as Map<dynamic, dynamic>;
      expect(session['routineId'], 'full_body');
    });

    test(
      'log_set event navigates to the exercise and records the set',
      () async {
        final seededState = DemoSeedData.initialState().copyWith(
          sessions: [buildActiveSession('push_day')],
        );
        final container = buildContainer(initialState: seededState);
        addTearDown(container.dispose);

        container.read(watchSyncServiceProvider).initialize();
        await pumpEvents();
        methodCalls.clear();

        watchEvents!.success(<String, Object?>{
          'type': 'log_set',
          'sessionId': 'session_active',
          'exerciseId': 'incline_dumbbell_press',
          'setNumber': 1,
          'weightKg': 24.0,
          'reps': 10,
        });
        await pumpEvents();

        final session = container
            .read(appStateControllerProvider)
            .activeSession;
        expect(session, isNotNull);
        expect(session!.currentExerciseIndex, 1);
        expect(session.completedSets, hasLength(1));
        expect(
          session.completedSets.single.exerciseId,
          'incline_dumbbell_press',
        );
        expect(session.completedSets.single.setNumber, 1);
        expect(session.completedSets.single.weightKg, 24.0);
        expect(session.completedSets.single.reps, 10);
      },
    );

    test('duplicate watch log_set events are ignored', () async {
      final seededState = DemoSeedData.initialState().copyWith(
        sessions: [buildActiveSession('push_day')],
      );
      final container = buildContainer(initialState: seededState);
      addTearDown(container.dispose);

      container.read(watchSyncServiceProvider).initialize();
      await pumpEvents();

      final workoutController = container.read(workoutControllerProvider);
      workoutController.goToExercise(1);
      workoutController.logSet(weightKg: 24.0, reps: 10);
      await pumpEvents();

      final before = container.read(appStateControllerProvider).activeSession!;
      expect(before.completedSets, hasLength(1));

      watchEvents!.success(<String, Object?>{
        'type': 'log_set',
        'sessionId': 'session_active',
        'exerciseId': 'incline_dumbbell_press',
        'setNumber': 1,
        'weightKg': 24.0,
        'reps': 10,
      });
      await pumpEvents();

      final after = container.read(appStateControllerProvider).activeSession!;
      expect(after.completedSets, hasLength(1));
      expect(after.completedSets.single.exerciseId, 'incline_dumbbell_press');
      expect(after.completedSets.single.setNumber, 1);
    });

    test(
      'stale watch log_set events from another session are ignored',
      () async {
        final seededState = DemoSeedData.initialState().copyWith(
          sessions: [buildActiveSession('push_day')],
        );
        final container = buildContainer(initialState: seededState);
        addTearDown(container.dispose);

        container.read(watchSyncServiceProvider).initialize();
        await pumpEvents();

        watchEvents!.success(<String, Object?>{
          'type': 'log_set',
          'sessionId': 'older_session',
          'exerciseId': 'incline_dumbbell_press',
          'setNumber': 1,
          'weightKg': 24.0,
          'reps': 10,
        });
        await pumpEvents();

        final session = container
            .read(appStateControllerProvider)
            .activeSession!;
        expect(session.currentExerciseIndex, 0);
        expect(session.completedSets, isEmpty);
      },
    );
  });
}
