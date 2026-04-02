import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

/// Helper to create a [UserProfile] for tests.
UserProfile _profile() => UserProfile(
      sex: Sex.male,
      age: 30,
      bodyWeightKg: 80.0,
      experience: ExperienceLevel.intermediate,
      goal: HypertrophyGoal.hypertrophy,
      availableDays: [1, 3, 5],
      maxSessionDuration: const Duration(hours: 1),
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('TrainingState.initial', () {
    test('creates empty state with provided profile', () {
      final profile = _profile();
      final state = TrainingState.initial(profile);

      expect(state.profile.sex, Sex.male);
      expect(state.e1rmHistory, isEmpty);
      expect(state.fatigueLog, isEmpty);
      expect(state.dailyLoads, isEmpty);
      expect(state.acwrState, isNull);
      expect(state.sleepHistory, isEmpty);
      expect(state.hrvHistory, isEmpty);
      expect(state.sessionsIngested, equals(0));
    });
  });

  group('TrainingState.copyWith', () {
    test('copies with sessionsIngested update', () {
      final state = TrainingState.initial(_profile());
      final updated = state.copyWith(sessionsIngested: 5);
      expect(updated.sessionsIngested, equals(5));
      expect(updated.profile.sex, equals(state.profile.sex));
    });

    test('copies with explicit null acwrState', () {
      final withAcwr = TrainingState.initial(_profile()).copyWith(
        acwrState: EwmaState(
          acuteEwma: 100,
          chronicEwma: 90,
          lastComputedDate: DateTime.utc(2026, 1, 10),
        ),
      );
      expect(withAcwr.acwrState, isNotNull);

      final cleared = withAcwr.copyWith(acwrState: null);
      expect(cleared.acwrState, isNull);
    });

    test('retains unchanged fields', () {
      final state = TrainingState.initial(_profile());
      final updated = state.copyWith(sessionsIngested: 3);
      expect(updated.e1rmHistory, same(state.e1rmHistory));
      expect(updated.fatigueLog, same(state.fatigueLog));
    });
  });

  group('TrainingState JSON roundtrip', () {
    test('empty state survives roundtrip', () {
      final state = TrainingState.initial(_profile());
      final json = state.toJson();
      final restored = TrainingState.fromJson(json);

      expect(restored.profile.sex.name, state.profile.sex.name);
      expect(restored.e1rmHistory, isEmpty);
      expect(restored.fatigueLog, isEmpty);
      expect(restored.dailyLoads, isEmpty);
      expect(restored.acwrState, isNull);
      expect(restored.sleepHistory, isEmpty);
      expect(restored.hrvHistory, isEmpty);
      expect(restored.sessionsIngested, equals(0));
    });

    test('populated state — e1rmHistory survives roundtrip', () {
      final state = TrainingState.initial(_profile()).copyWith(
        e1rmHistory: {
          'barbell_bench_press': [
            E1rmEstimate(
              exerciseId: 'barbell_bench_press',
              value: 100.0,
              rMax: 1.0,
              confidence: 0.9,
              estimatedAt: DateTime.utc(2026, 2, 1),
              fromEstimatedRpe: false,
            ),
            E1rmEstimate(
              exerciseId: 'barbell_bench_press',
              value: 102.5,
              rMax: 1.0,
              confidence: 0.95,
              estimatedAt: DateTime.utc(2026, 2, 8),
              fromEstimatedRpe: false,
            ),
          ],
        },
        sessionsIngested: 2,
      );

      final restored = TrainingState.fromJson(state.toJson());

      expect(restored.e1rmHistory.length, equals(1));
      expect(
        restored.e1rmHistory['barbell_bench_press']!.length,
        equals(2),
      );
      expect(
        restored.e1rmHistory['barbell_bench_press']!.first.value,
        closeTo(100.0, 0.001),
      );
      expect(
        restored.e1rmHistory['barbell_bench_press']!.last.value,
        closeTo(102.5, 0.001),
      );
      expect(restored.sessionsIngested, equals(2));
    });

    test('populated state — fatigueLog survives roundtrip', () {
      final state = TrainingState.initial(_profile()).copyWith(
        fatigueLog: {
          'pectorals': [
            FatigueImpulse(
              muscleId: 'pectorals',
              magnitude: 250.0,
              timestamp: DateTime.utc(2026, 2, 1),
            ),
          ],
          'quads': [
            FatigueImpulse(
              muscleId: 'quads',
              magnitude: 300.0,
              timestamp: DateTime.utc(2026, 2, 2),
            ),
          ],
        },
      );

      final restored = TrainingState.fromJson(state.toJson());

      expect(restored.fatigueLog.length, equals(2));
      expect(restored.fatigueLog['pectorals']!.first.magnitude, closeTo(250.0, 0.001));
      expect(restored.fatigueLog['quads']!.first.muscleId, equals('quads'));
    });

    test('populated state — dailyLoads survives roundtrip', () {
      final state = TrainingState.initial(_profile()).copyWith(
        dailyLoads: [
          DailyLoad(
            date: DateTime.utc(2026, 2, 1),
            volumeLoad: 5000.0,
            sRpeLoad: 420.0,
          ),
          DailyLoad(
            date: DateTime.utc(2026, 2, 3),
            volumeLoad: 6500.0,
          ),
        ],
      );

      final restored = TrainingState.fromJson(state.toJson());

      expect(restored.dailyLoads.length, equals(2));
      expect(restored.dailyLoads.first.volumeLoad, closeTo(5000.0, 0.001));
      expect(restored.dailyLoads.first.sRpeLoad, closeTo(420.0, 0.001));
      expect(restored.dailyLoads.last.sRpeLoad, isNull);
    });

    test('populated state — acwrState survives roundtrip', () {
      final ewma = EwmaState(
        acuteEwma: 450.0,
        chronicEwma: 380.0,
        lastComputedDate: DateTime.utc(2026, 2, 10),
      );
      final state = TrainingState.initial(_profile()).copyWith(acwrState: ewma);

      final restored = TrainingState.fromJson(state.toJson());

      expect(restored.acwrState, isNotNull);
      expect(restored.acwrState!.acuteEwma, closeTo(450.0, 0.001));
      expect(restored.acwrState!.chronicEwma, closeTo(380.0, 0.001));
    });

    test('populated state — sleepHistory survives roundtrip', () {
      final state = TrainingState.initial(_profile()).copyWith(
        sleepHistory: [
          SleepRecord(
            date: DateTime.utc(2026, 2, 1),
            totalSleep: const Duration(hours: 7, minutes: 30),
            deepSleep: const Duration(hours: 1, minutes: 45),
            remSleep: const Duration(hours: 2),
            coreSleep: const Duration(hours: 3, minutes: 45),
          ),
        ],
      );

      final restored = TrainingState.fromJson(state.toJson());

      expect(restored.sleepHistory.length, equals(1));
      expect(restored.sleepHistory.first.totalSleep.inMinutes, equals(450));
    });

    test('populated state — hrvHistory survives roundtrip', () {
      final state = TrainingState.initial(_profile()).copyWith(
        hrvHistory: [
          HrvRecord(
            date: DateTime.utc(2026, 2, 1),
            sdnn: 62.5,
            restingHeartRate: 52.0,
          ),
          HrvRecord(
            date: DateTime.utc(2026, 2, 2),
            sdnn: 58.0,
          ),
        ],
      );

      final restored = TrainingState.fromJson(state.toJson());

      expect(restored.hrvHistory.length, equals(2));
      expect(restored.hrvHistory.first.sdnn, closeTo(62.5, 0.001));
      expect(restored.hrvHistory.first.restingHeartRate, closeTo(52.0, 0.001));
      expect(restored.hrvHistory.last.restingHeartRate, isNull);
    });

    test('fully populated state — all collections survive roundtrip', () {
      final state = TrainingState(
        profile: _profile(),
        e1rmHistory: {
          'barbell_back_squat': [
            E1rmEstimate(
              exerciseId: 'barbell_back_squat',
              value: 140.0,
              rMax: 1.0,
              confidence: 0.85,
              estimatedAt: DateTime.utc(2026, 3, 1),
              fromEstimatedRpe: false,
            ),
          ],
        },
        fatigueLog: {
          'quad': [
            FatigueImpulse(
              muscleId: 'quad',
              magnitude: 400.0,
              timestamp: DateTime.utc(2026, 3, 1),
            ),
          ],
        },
        dailyLoads: [
          DailyLoad(
            date: DateTime.utc(2026, 3, 1),
            volumeLoad: 8000.0,
            sRpeLoad: 560.0,
          ),
        ],
        acwrState: EwmaState(
          acuteEwma: 520.0,
          chronicEwma: 490.0,
          lastComputedDate: DateTime.utc(2026, 3, 1),
        ),
        sleepHistory: [
          SleepRecord(
            date: DateTime.utc(2026, 3, 1),
            totalSleep: const Duration(hours: 8),
            deepSleep: const Duration(hours: 2),
            remSleep: const Duration(hours: 2),
            coreSleep: const Duration(hours: 4),
          ),
        ],
        hrvHistory: [
          HrvRecord(
            date: DateTime.utc(2026, 3, 1),
            sdnn: 70.0,
            restingHeartRate: 50.0,
          ),
        ],
        lastTopSets: {
          'barbell_back_squat': LoggedSet(
            exerciseId: 'barbell_back_squat',
            weightKg: 130.0,
            reps: 5,
            rpe: 8.0,
            completedAt: DateTime.utc(2026, 3, 1),
          ),
        },
        lastUpdated: DateTime.utc(2026, 3, 2),
        sessionsIngested: 10,
      );

      final json = state.toJson();
      final restored = TrainingState.fromJson(json);

      // Spot-check each collection
      expect(restored.e1rmHistory['barbell_back_squat']!.first.value, closeTo(140.0, 0.001));
      expect(restored.fatigueLog['quad']!.first.magnitude, closeTo(400.0, 0.001));
      expect(restored.dailyLoads.first.volumeLoad, closeTo(8000.0, 0.001));
      expect(restored.acwrState!.acuteEwma, closeTo(520.0, 0.001));
      expect(restored.sleepHistory.first.totalSleep.inHours, equals(8));
      expect(restored.hrvHistory.first.sdnn, closeTo(70.0, 0.001));
      expect(restored.lastTopSets['barbell_back_squat']!.weightKg, closeTo(130.0, 0.001));
      expect(restored.lastUpdated, equals(DateTime.utc(2026, 3, 2)));
      expect(restored.sessionsIngested, equals(10));
    });
  });
}
