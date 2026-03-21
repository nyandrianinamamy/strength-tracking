import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

final staleSessionServiceProvider = Provider<StaleSessionService>((ref) {
  return const StaleSessionService();
});

class StaleSessionService {
  const StaleSessionService({
    this.staleAfter = const Duration(minutes: 90),
  });

  final Duration staleAfter;

  DateTime lastActivityAt(WorkoutSession session) {
    if (session.lastActivityAt != null) {
      return session.lastActivityAt!;
    }

    if (session.completedSets.isEmpty) {
      return session.startedAt;
    }

    return session.completedSets
        .map((set) => set.completedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  bool isStale(
    WorkoutSession session, {
    DateTime? now,
  }) {
    if (session.status != WorkoutSessionStatus.active) {
      return false;
    }
    final effectiveNow = now ?? DateTime.now();
    return effectiveNow.difference(lastActivityAt(session)) >= staleAfter;
  }

  Duration idleDuration(
    WorkoutSession session, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    return effectiveNow.difference(lastActivityAt(session));
  }

  String idleLabel(
    WorkoutSession session, {
    DateTime? now,
  }) {
    final duration = idleDuration(session, now: now);
    if (duration.inHours >= 1) {
      final hours = duration.inHours;
      return hours == 1 ? '1 hour idle' : '$hours hours idle';
    }
    final minutes = duration.inMinutes.clamp(1, 59);
    return minutes == 1 ? '1 minute idle' : '$minutes minutes idle';
  }
}
