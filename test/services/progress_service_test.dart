import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';

void main() {
  final service = ProgressService();

  test('dashboard snapshot exposes recent workouts and a next routine', () {
    final state = DemoSeedData.initialState();
    final snapshot = service.dashboardSnapshot(state);

    expect(snapshot.totalWorkouts, greaterThan(0));
    expect(snapshot.nextRoutine, isNotNull);
    expect(snapshot.recentWorkouts, isNotEmpty);
    expect(snapshot.monthFrequency.days, hasLength(42));
  });

  test('progress snapshot computes streak, volume, and personal records', () {
    final state = DemoSeedData.initialState();
    final snapshot = service.progressSnapshot(state);

    expect(snapshot.averageWorkoutDaysPerWeek, greaterThan(0));
    expect(snapshot.personalRecords, isNotEmpty);
    expect(snapshot.weeklyVolume, isNotEmpty);
    expect(snapshot.topLifts.first.estimatedOneRepMax, greaterThan(0));
  });

  test('session PRs detect new performance inside a completed workout', () {
    final state = DemoSeedData.initialState();
    final prs = service.sessionPrs(state, 'session_leg_2');

    expect(prs, isNotEmpty);
    expect(prs.any((record) => record.exerciseId == 'back_squat'), isTrue);
  });
}
