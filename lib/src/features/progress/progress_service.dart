import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

final progressServiceProvider = Provider<ProgressService>((ref) {
  return ProgressService();
});

class ProgressService {
  DashboardSnapshot dashboardSnapshot(AppState state) {
    final completedSessions = state.completedSessions;
    final recentWorkouts = completedSessions
        .take(4)
        .map(
          (session) => RecentWorkoutSummary(
            sessionId: session.id,
            routineName:
                state.routineById(session.routineId)?.name ?? 'Workout',
            date: session.endedAt ?? session.startedAt,
            duration: (session.endedAt ?? session.startedAt).difference(
              session.startedAt,
            ),
            totalVolumeKg: _sessionVolume(session),
          ),
        )
        .toList();

    final now = DateTime.now();
    final thisWeekCount = completedSessions
        .where(
          (session) => (session.endedAt ?? session.startedAt).isAfter(
            now.subtract(const Duration(days: 7)),
          ),
        )
        .length;
    final previousWeekCount = completedSessions.where((session) {
      final date = session.endedAt ?? session.startedAt;
      return date.isAfter(now.subtract(const Duration(days: 14))) &&
          date.isBefore(now.subtract(const Duration(days: 7)));
    }).length;

    final activeSession = state.activeSession;
    final selectedRoutine = activeSession != null
        ? state.routineById(activeSession.routineId)
        : _pickNextRoutine(state);
    final personalRecords = _personalRecords(state);

    return DashboardSnapshot(
      totalWorkouts: completedSessions.length,
      workoutDelta: thisWeekCount - previousWeekCount,
      personalRecordCount: personalRecords.length,
      nextRoutine: selectedRoutine,
      activeSession: activeSession,
      recentWorkouts: recentWorkouts,
      monthFrequency: _monthFrequency(
        completedSessions,
        DateTime(now.year, now.month),
      ),
      recentPrs: personalRecords.take(3).toList(),
    );
  }

  ProgressSnapshot progressSnapshot(AppState state) {
    final completedSessions = state.completedSessions;
    final personalRecords = _personalRecords(state);
    final earliest = completedSessions.isEmpty
        ? DateTime.now()
        : (completedSessions.last.endedAt ?? completedSessions.last.startedAt);
    final weeksSpan = math
        .max(1, DateTime.now().difference(earliest).inDays / 7)
        .toDouble();

    return ProgressSnapshot(
      averageWorkoutDaysPerWeek: completedSessions.length / weeksSpan,
      activeStreakDays: _activeStreakDays(completedSessions),
      monthFrequency: _monthFrequency(
        completedSessions,
        DateTime(DateTime.now().year, DateTime.now().month),
      ),
      personalRecords: personalRecords,
      weeklyVolume: _weeklyVolume(completedSessions),
      topLifts: personalRecords
          .map(
            (record) => LiftMetric(
              exerciseId: record.exerciseId,
              exerciseName: record.exerciseName,
              estimatedOneRepMax: record.estimatedOneRepMax,
              bestSetWeightKg: record.weightKg,
              reps: record.reps,
              achievedAt: record.achievedAt,
            ),
          )
          .toList(),
    );
  }

  List<ExercisePersonalRecord> sessionPrs(AppState state, String sessionId) {
    final session = state.sessionById(sessionId);
    if (session == null) {
      return const [];
    }

    final records = <ExercisePersonalRecord>[];

    for (final set in session.completedSets) {
      final e1rm = _estimatedOneRepMax(set);
      final allSets = state.completedSessions
          .where((item) => item.id != session.id)
          .expand((item) => item.completedSets)
          .where((item) => item.exerciseId == set.exerciseId);
      final priorBest = allSets.fold<double>(0, (best, item) {
        return math.max(best, _estimatedOneRepMax(item));
      });

      if (e1rm > priorBest) {
        final exerciseName =
            state.exerciseById(set.exerciseId)?.name ?? 'Exercise';
        final record = ExercisePersonalRecord(
          exerciseId: set.exerciseId,
          exerciseName: exerciseName,
          weightKg: set.weightKg,
          reps: set.reps,
          estimatedOneRepMax: e1rm,
          achievedAt: set.completedAt,
        );

        if (records.every((item) => item.exerciseId != record.exerciseId)) {
          records.add(record);
        }
      }
    }

    records.sort(
      (a, b) => b.estimatedOneRepMax.compareTo(a.estimatedOneRepMax),
    );
    return records;
  }

  Routine? _pickNextRoutine(AppState state) {
    final available = state.routines
        .where((routine) => !routine.archived)
        .toList();
    if (available.isEmpty) {
      return null;
    }

    final latestCompleted = state.completedSessions.isEmpty
        ? null
        : state.completedSessions.first;
    if (latestCompleted == null) {
      return available.first;
    }

    return state.routineById(latestCompleted.routineId) ?? available.first;
  }

  double _sessionVolume(WorkoutSession session) {
    return session.completedSets.fold<double>(
      0,
      (total, set) => total + (set.weightKg * set.reps),
    );
  }

  double _estimatedOneRepMax(CompletedSet set) {
    return set.weightKg * (1 + (set.reps / 30));
  }

  List<ExercisePersonalRecord> _personalRecords(AppState state) {
    final bestByExercise = <String, ExercisePersonalRecord>{};

    for (final session in state.completedSessions) {
      for (final set in session.completedSets) {
        final record = ExercisePersonalRecord(
          exerciseId: set.exerciseId,
          exerciseName: state.exerciseById(set.exerciseId)?.name ?? 'Exercise',
          weightKg: set.weightKg,
          reps: set.reps,
          estimatedOneRepMax: _estimatedOneRepMax(set),
          achievedAt: set.completedAt,
        );

        final existing = bestByExercise[set.exerciseId];
        if (existing == null ||
            record.estimatedOneRepMax > existing.estimatedOneRepMax ||
            (record.estimatedOneRepMax == existing.estimatedOneRepMax &&
                record.achievedAt.isAfter(existing.achievedAt))) {
          bestByExercise[set.exerciseId] = record;
        }
      }
    }

    final records = bestByExercise.values.toList()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    return records;
  }

  MonthFrequency _monthFrequency(
    List<WorkoutSession> sessions,
    DateTime month,
  ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final offset = firstDay.weekday % 7;
    final start = firstDay.subtract(Duration(days: offset));
    final days = <CalendarDayEntry>[];
    final counts = <String, int>{};

    for (final session in sessions) {
      final date = session.endedAt ?? session.startedAt;
      final key = _dateKey(date);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    for (var index = 0; index < 42; index++) {
      final date = start.add(Duration(days: index));
      days.add(
        CalendarDayEntry(
          date: date,
          inMonth: date.month == month.month,
          workouts: counts[_dateKey(date)] ?? 0,
          isToday: _isSameDay(date, DateTime.now()),
        ),
      );
    }

    return MonthFrequency(month: month, days: days);
  }

  int _activeStreakDays(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) {
      return 0;
    }

    final workoutDays = sessions.map((session) {
      final date = session.endedAt ?? session.startedAt;
      return DateTime(date.year, date.month, date.day);
    }).toSet();

    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    if (!workoutDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!workoutDays.contains(cursor)) {
        return 0;
      }
    }

    var streak = 0;
    while (workoutDays.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<VolumePoint> _weeklyVolume(List<WorkoutSession> sessions) {
    final totals = <DateTime, double>{};

    for (final session in sessions) {
      final date = session.endedAt ?? session.startedAt;
      final startOfWeek = DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: date.weekday - 1));
      totals[startOfWeek] =
          (totals[startOfWeek] ?? 0) + _sessionVolume(session);
    }

    final points =
        totals.entries
            .map(
              (entry) =>
                  VolumePoint(weekStart: entry.key, totalVolumeKg: entry.value),
            )
            .toList()
          ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
    return points;
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalWorkouts,
    required this.workoutDelta,
    required this.personalRecordCount,
    required this.nextRoutine,
    required this.activeSession,
    required this.recentWorkouts,
    required this.monthFrequency,
    required this.recentPrs,
  });

  final int totalWorkouts;
  final int workoutDelta;
  final int personalRecordCount;
  final Routine? nextRoutine;
  final WorkoutSession? activeSession;
  final List<RecentWorkoutSummary> recentWorkouts;
  final MonthFrequency monthFrequency;
  final List<ExercisePersonalRecord> recentPrs;
}

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.averageWorkoutDaysPerWeek,
    required this.activeStreakDays,
    required this.monthFrequency,
    required this.personalRecords,
    required this.weeklyVolume,
    required this.topLifts,
  });

  final double averageWorkoutDaysPerWeek;
  final int activeStreakDays;
  final MonthFrequency monthFrequency;
  final List<ExercisePersonalRecord> personalRecords;
  final List<VolumePoint> weeklyVolume;
  final List<LiftMetric> topLifts;
}

class RecentWorkoutSummary {
  const RecentWorkoutSummary({
    required this.sessionId,
    required this.routineName,
    required this.date,
    required this.duration,
    required this.totalVolumeKg,
  });

  final String sessionId;
  final String routineName;
  final DateTime date;
  final Duration duration;
  final double totalVolumeKg;
}

class ExercisePersonalRecord {
  const ExercisePersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.estimatedOneRepMax,
    required this.achievedAt,
  });

  final String exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final double estimatedOneRepMax;
  final DateTime achievedAt;
}

class MonthFrequency {
  const MonthFrequency({required this.month, required this.days});

  final DateTime month;
  final List<CalendarDayEntry> days;
}

class CalendarDayEntry {
  const CalendarDayEntry({
    required this.date,
    required this.inMonth,
    required this.workouts,
    required this.isToday,
  });

  final DateTime date;
  final bool inMonth;
  final int workouts;
  final bool isToday;
}

class VolumePoint {
  const VolumePoint({required this.weekStart, required this.totalVolumeKg});

  final DateTime weekStart;
  final double totalVolumeKg;
}

class LiftMetric {
  const LiftMetric({
    required this.exerciseId,
    required this.exerciseName,
    required this.estimatedOneRepMax,
    required this.bestSetWeightKg,
    required this.reps,
    required this.achievedAt,
  });

  final String exerciseId;
  final String exerciseName;
  final double estimatedOneRepMax;
  final double bestSetWeightKg;
  final int reps;
  final DateTime achievedAt;
}
