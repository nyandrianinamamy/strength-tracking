import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:training_engine/training_engine.dart';

import '../../shared/widgets/common_widgets.dart';
import '../training_engine/training_engine_provider.dart';

class TrainingReadinessCard extends ConsumerWidget {
  const TrainingReadinessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineAsync = ref.watch(trainingEngineProvider);

    return engineAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => const EmptyStateCard(
        title: 'Adaptive Readiness',
        body: 'Adaptive guidance is temporarily unavailable.',
      ),
      data: (engine) {
        if (engine.state.sessionsIngested == 0) {
          return const EmptyStateCard(
            title: 'Adaptive Readiness',
            body: 'Complete a workout to unlock adaptive guidance.',
          );
        }

        final readinessAsync = ref.watch(readinessProvider);
        return readinessAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stackTrace) => const EmptyStateCard(
            title: 'Adaptive Readiness',
            body: 'Adaptive guidance is temporarily unavailable.',
          ),
          data: (readiness) => _ReadinessSummary(readiness: readiness),
        );
      },
    );
  }
}

class _ReadinessSummary extends StatelessWidget {
  const _ReadinessSummary({required this.readiness});

  final ReadinessScore readiness;

  @override
  Widget build(BuildContext context) {
    final score = readiness.score.round().clamp(0, 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adaptive Readiness',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _headlineForScore(score),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Readiness score $score/100',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Confidence: ${readiness.confidence.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _headlineForScore(int score) {
    if (score >= 75) {
      return 'Ready to push';
    }
    if (score >= 55) {
      return 'Recovering well';
    }
    return 'Take it lighter';
  }
}
