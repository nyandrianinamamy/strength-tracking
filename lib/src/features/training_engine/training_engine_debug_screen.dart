import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:training_engine/training_engine.dart';

import 'training_engine_provider.dart';

class TrainingEngineDebugScreen extends ConsumerWidget {
  const TrainingEngineDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineAsync = ref.watch(trainingEngineProvider);
    final readinessAsync = ref.watch(readinessProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Training Engine Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          engineAsync.when(
            loading: _loadingCard,
            error: (error, stack) => _DebugErrorCard(error: error),
            data: (engine) => _EngineStatusCard(engine: engine),
          ),
          const SizedBox(height: 16),
          readinessAsync.when(
            loading: _loadingCard,
            error: (error, stack) => _DebugErrorCard(error: error),
            data: (readiness) => _ReadinessCard(readiness: readiness),
          ),
        ],
      ),
    );
  }

  static Widget _loadingCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EngineStatusCard extends StatelessWidget {
  const _EngineStatusCard({required this.engine});

  final TrainingEngine engine;

  @override
  Widget build(BuildContext context) {
    final state = engine.state;
    return _SectionCard(
      title: 'Engine Status',
      children: [
        _KvRow(
          label: 'sessions ingested',
          value: state.sessionsIngested.toString(),
        ),
        _KvRow(
          label: 'Last updated',
          value: state.lastUpdated.toLocal().toIso8601String(),
        ),
        _KvRow(
          label: 'Sleep records',
          value: state.sleepHistory.length.toString(),
        ),
        _KvRow(label: 'HRV records', value: state.hrvHistory.length.toString()),
        _KvRow(label: 'Daily loads', value: state.dailyLoads.length.toString()),
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness});

  final ReadinessScore readiness;

  @override
  Widget build(BuildContext context) {
    final componentScores = readiness.componentScores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final flags = readiness.flags.map((flag) => flag.name).toList();

    return _SectionCard(
      title: 'Readiness Breakdown',
      children: [
        _KvRow(
          label: 'Readiness score',
          value: '${readiness.score.toStringAsFixed(1)}/100',
        ),
        _KvRow(label: 'confidence', value: readiness.confidence.name),
        _KvRow(label: 'Tier', value: readiness.tier.name),
        _KvRow(
          label: 'Flags',
          value: flags.isEmpty ? 'None' : flags.join(', '),
        ),
        const SizedBox(height: 8),
        Text(
          'Component scores',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (componentScores.isEmpty)
          const Text('No component scores available.')
        else
          ...componentScores.map(
            (entry) =>
                _KvRow(label: entry.key, value: entry.value.toStringAsFixed(1)),
          ),
      ],
    );
  }
}

class _DebugErrorCard extends StatelessWidget {
  const _DebugErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Debug data unavailable: $error',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
