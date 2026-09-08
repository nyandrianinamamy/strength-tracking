import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/live_activity/workout_live_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.strengthapp/live_activity');

  ProviderContainer buildContainer({required List<WorkoutSession> sessions}) {
    final repository = MemoryAppStateRepository(
      initialState: DemoSeedData.initialState().copyWith(sessions: sessions),
    );

    return ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
      ],
    );
  }

  WorkoutSession activeSession({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return WorkoutSession(
      id: 'session_live',
      routineId: 'push_day',
      status: WorkoutSessionStatus.active,
      startedAt: timestamp.subtract(const Duration(minutes: 18)),
      endedAt: null,
      lastActivityAt: timestamp.subtract(const Duration(seconds: 20)),
      currentExerciseIndex: 1,
      completedSets: [
        CompletedSet(
          exerciseId: 'incline_dumbbell_press',
          setNumber: 1,
          weightKg: 24,
          reps: 10,
          completedAt: timestamp.subtract(const Duration(seconds: 20)),
          note: '',
        ),
      ],
      sessionNote: '',
      rpe: null,
    );
  }

  Future<void> pumpEvents() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('WorkoutLiveActivityPayload', () {
    test('French payload localizes companion labels and exercise names', () {
      final state = DemoSeedData.initialState().copyWith(
        sessions: [activeSession()],
        preferredLanguage: 'fr',
      );
      final payload = WorkoutLiveActivityPayload.fromState(state)!;
      expect(payload.locale, 'fr');
      expect(payload.completedSetsText, contains('séries'));
      expect(payload.currentExerciseProgressText, contains('séries'));
      expect(payload.exerciseDetailText, contains('répétitions'));
      expect(payload.currentExerciseName, isNot('Incline Dumbbell Press'));
      expect(payload.toMap()['locale'], 'fr');
    });

    test('returns null when there is no active session', () {
      final state = DemoSeedData.initialState();

      expect(WorkoutLiveActivityPayload.fromState(state), isNull);
    });

    test('builds payload for an active strength workout with rest', () {
      final now = DateTime.now();
      final session = WorkoutSession(
        id: 'session_live',
        routineId: 'push_day',
        status: WorkoutSessionStatus.active,
        startedAt: now.subtract(const Duration(minutes: 18)),
        endedAt: null,
        lastActivityAt: now.subtract(const Duration(seconds: 20)),
        currentExerciseIndex: 1,
        completedSets: [
          CompletedSet(
            exerciseId: 'incline_dumbbell_press',
            setNumber: 1,
            weightKg: 24,
            reps: 10,
            completedAt: now.subtract(const Duration(seconds: 20)),
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: null,
      );

      final state = DemoSeedData.initialState().copyWith(sessions: [session]);
      final payload = WorkoutLiveActivityPayload.fromState(state);

      expect(payload, isNotNull);
      expect(payload!.sessionId, 'session_live');
      expect(payload.routineName, 'Push Day');
      expect(payload.currentExerciseName, 'Incline Dumbbell Press');
      expect(payload.currentExerciseProgressText, '1/3 sets');
      expect(payload.exerciseDetailText, '10 reps target');
      expect(payload.hasActiveRest, isTrue);
      expect(payload.restEndAt, isNotNull);
    });

    test('omits rest when the most recent rest window has expired', () {
      final now = DateTime.now();
      final session = WorkoutSession(
        id: 'session_live',
        routineId: 'push_day',
        status: WorkoutSessionStatus.active,
        startedAt: now.subtract(const Duration(minutes: 18)),
        endedAt: null,
        lastActivityAt: now.subtract(const Duration(minutes: 5)),
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_bench_press',
            setNumber: 1,
            weightKg: 60,
            reps: 8,
            completedAt: now.subtract(const Duration(minutes: 5)),
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: null,
      );

      final state = DemoSeedData.initialState().copyWith(sessions: [session]);
      final payload = WorkoutLiveActivityPayload.fromState(state);

      expect(payload, isNotNull);
      expect(payload!.hasActiveRest, isFalse);
      expect(payload.restEndAt, isNull);
      expect(payload.restSeconds, 0);
    });
  });

  group('WorkoutLiveActivityService', () {
    late TestDefaultBinaryMessenger messenger;
    late List<MethodCall> methodCalls;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      methodCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        methodCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(methodChannel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('initialize syncs active workout only once', () async {
      final container = buildContainer(sessions: [activeSession()]);
      addTearDown(container.dispose);

      final service = container.read(workoutLiveActivityServiceProvider);
      service.initialize();
      service.initialize();
      await pumpEvents();

      final syncCalls = methodCalls
          .where((call) => call.method == 'syncWorkout')
          .toList();
      expect(syncCalls, hasLength(1));

      final payload = syncCalls.single.arguments as Map<dynamic, dynamic>;
      expect(payload['sessionId'], 'session_live');
      expect(payload['routineName'], 'Push Day');
      expect(payload['currentExerciseName'], 'Incline Dumbbell Press');
      expect(payload['currentExerciseIndex'], 2);
      expect(payload['totalExercises'], 6);
      expect(payload['completedSetsText'], '1 total sets');
      expect(payload['currentExerciseProgressText'], '1/3 sets');
      expect(payload['exerciseDetailText'], '10 reps target');
      expect(payload['startedAt'], isA<String>());
      expect(payload['updatedAt'], isA<String>());
      expect(payload['lastSetAt'], isA<String>());
      expect(payload['restEndAt'], isA<String>());
      expect(payload['restSeconds'], 90);
      expect(payload['hasActiveRest'], isTrue);
    });

    test('ending the active workout sends endWorkout', () async {
      final container = buildContainer(sessions: [activeSession()]);
      addTearDown(container.dispose);

      container.read(workoutLiveActivityServiceProvider).initialize();
      await pumpEvents();
      methodCalls.clear();

      container
          .read(appStateControllerProvider.notifier)
          .updateState((state) => state.copyWith(sessions: const []));
      await pumpEvents();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'endWorkout');
    });

    test('method-channel failures do not escape initialization', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        methodCalls.add(call);
        throw PlatformException(code: 'channel-unavailable');
      });
      final container = buildContainer(sessions: [activeSession()]);
      addTearDown(container.dispose);

      container.read(workoutLiveActivityServiceProvider).initialize();
      await pumpEvents();

      expect(methodCalls.single.method, 'syncWorkout');
    });
  });
}
