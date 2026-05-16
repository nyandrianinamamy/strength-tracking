import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/watch/watch_sync_service.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.strengthapp/watch');
  const eventChannel = EventChannel('com.strengthapp/watch_events');

  ProviderContainer buildContainer({
    AppState? initialState,
    TrainingEngineStateRepository? trainingEngineRepository,
  }) {
    final repository = MemoryAppStateRepository(
      initialState: initialState ?? DemoSeedData.initialState(),
    );

    return ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
        trainingEngineStateRepositoryProvider.overrideWithValue(
          trainingEngineRepository ?? MemoryTrainingEngineStateRepository(),
        ),
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
      lastActivityAt: DateTime(2026, 3, 21, 9),
      currentExerciseIndex: 0,
      completedSets: const [],
      sessionNote: '',
      rpe: null,
    );
  }

  WorkoutSession buildCompletedBenchSession() {
    return WorkoutSession(
      id: 'watch-session',
      routineId: 'push_day',
      status: WorkoutSessionStatus.completed,
      startedAt: DateTime.utc(2026, 4, 1, 17, 0),
      endedAt: DateTime.utc(2026, 4, 1, 18, 0),
      lastActivityAt: DateTime.utc(2026, 4, 1, 18, 0),
      currentExerciseIndex: 0,
      completedSets: [
        CompletedSet(
          exerciseId: 'barbell_bench_press',
          setNumber: 1,
          weightKg: 80,
          reps: 12,
          completedAt: DateTime.utc(2026, 4, 1, 17, 15),
          note: '',
          rpe: 8.0,
        ),
      ],
      sessionNote: '',
      rpe: 8,
    );
  }

  Future<void> pumpEvents() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  void expectNoNullValues(Object? value) {
    expect(value, isNotNull);
    if (value is Map) {
      for (final entry in value.entries) {
        expect(entry.key, isNotNull);
        expectNoNullValues(entry.value as Object?);
      }
    } else if (value is Iterable) {
      for (final item in value) {
        expectNoNullValues(item as Object?);
      }
    }
  }

  Map<String, dynamic> savedEngineState() {
    final engine = TrainingEngine(
      registry: ExerciseRegistry.withDefaults(),
      profile: UserProfile(
        sex: Sex.male,
        age: 28,
        bodyWeightKg: 80,
        experience: ExperienceLevel.intermediate,
        goal: HypertrophyGoal.hypertrophy,
        availableDays: const [1, 3, 5],
        maxSessionDuration: const Duration(minutes: 60),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    engine.ingestSession(
      EngineSession(
        id: 'watch-session',
        startedAt: DateTime.utc(2026, 4, 1, 17, 0),
        endedAt: DateTime.utc(2026, 4, 1, 18, 0),
        sets: [
          LoggedSet(
            exerciseId: 'barbell_bench_press',
            weightKg: 80,
            reps: 12,
            rpe: 8.0,
            completedAt: DateTime.utc(2026, 4, 1, 17, 15),
          ),
        ],
      ),
    );

    return engine.serializeState();
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
        expectNoNullValues(arguments);
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

    test('initialize listens and syncs only once', () async {
      final seededState = DemoSeedData.initialState().copyWith(
        sessions: [buildActiveSession('push_day')],
      );
      final container = buildContainer(initialState: seededState);
      addTearDown(container.dispose);

      final service = container.read(watchSyncServiceProvider);
      service.initialize();
      service.initialize();
      await pumpEvents();

      expect(
        methodCalls.where((call) => call.method == 'sendSessionUpdate'),
        hasLength(1),
      );

      methodCalls.clear();
      watchEvents!.success(<String, Object?>{'type': 'request_sync'});
      await pumpEvents();

      expect(
        methodCalls.where((call) => call.method == 'sendSessionUpdate'),
        hasLength(1),
      );
    });

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

    test('watch snapshot uses engine recommendation when available', () async {
      final seededState = DemoSeedData.initialState().copyWith(
        sessions: [
          buildCompletedBenchSession(),
          buildActiveSession('push_day'),
        ],
      );
      final container = buildContainer(
        initialState: seededState,
        trainingEngineRepository: MemoryTrainingEngineStateRepository(
          initialState: savedEngineState(),
        ),
      );
      addTearDown(container.dispose);

      container.read(watchSyncServiceProvider).initialize();
      await pumpEvents();

      final arguments = methodCalls.single.arguments as Map<dynamic, dynamic>;
      final session = arguments['session'] as Map<dynamic, dynamic>;
      final exercises = session['exercises'] as List<dynamic>;
      final bench = exercises
          .map((item) => item as Map<dynamic, dynamic>)
          .firstWhere((item) => item['exerciseId'] == 'barbell_bench_press');

      expect(bench['suggestedWeightKg'], greaterThan(0));
    });

    test('watch snapshot omits recommendation when none exists', () async {
      final seededState = DemoSeedData.initialState().copyWith(
        sessions: [buildActiveSession('push_day')],
      );
      final container = buildContainer(initialState: seededState);
      addTearDown(container.dispose);

      container.read(watchSyncServiceProvider).initialize();
      await pumpEvents();

      final arguments = methodCalls.single.arguments as Map<dynamic, dynamic>;
      final session = arguments['session'] as Map<dynamic, dynamic>;
      final exercises = session['exercises'] as List<dynamic>;
      final bench = exercises
          .map((item) => item as Map<dynamic, dynamic>)
          .firstWhere((item) => item['exerciseId'] == 'barbell_bench_press');

      expect(bench, isNot(contains('suggestedWeightKg')));
    });

    test('watch snapshot includes active rest from the latest set', () async {
      final completedAt = DateTime.now().subtract(const Duration(seconds: 15));
      final activeSession = buildActiveSession('push_day').copyWith(
        currentExerciseIndex: 1,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_bench_press',
            setNumber: 1,
            weightKg: 80,
            reps: 8,
            completedAt: completedAt,
            note: '',
            rpe: 8,
          ),
        ],
      );
      final seededState = DemoSeedData.initialState().copyWith(
        sessions: [activeSession],
      );
      final container = buildContainer(initialState: seededState);
      addTearDown(container.dispose);

      container.read(watchSyncServiceProvider).initialize();
      await pumpEvents();

      final arguments = methodCalls.single.arguments as Map<dynamic, dynamic>;
      final session = arguments['session'] as Map<dynamic, dynamic>;
      final activeRest = session['activeRest'] as Map<dynamic, dynamic>;

      expect(activeRest['sourceExerciseId'], 'barbell_bench_press');
      expect(activeRest['sourceExerciseName'], isNotEmpty);
      expect(activeRest['startedAt'], completedAt.toUtc().toIso8601String());
      expect(
        activeRest['endsAt'],
        completedAt.add(const Duration(seconds: 120)).toUtc().toIso8601String(),
      );
      expect(activeRest['restSeconds'], 120);
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
      'watch-originated log events are ignored in display-only mode',
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

        watchEvents!.success(<String, Object?>{
          'type': 'log_timed_set',
          'sessionId': 'session_active',
          'exerciseId': 'flow_core_timer',
          'setNumber': 1,
          'durationSeconds': 45,
        });
        await pumpEvents();

        final session = container
            .read(appStateControllerProvider)
            .activeSession!;
        expect(session.currentExerciseIndex, 0);
        expect(session.completedSets, isEmpty);
        expect(methodCalls, isEmpty);
      },
    );
  });
}
