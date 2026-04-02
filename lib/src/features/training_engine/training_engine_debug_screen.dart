import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:training_engine/training_engine.dart';

import 'training_engine_provider.dart';

class TrainingEngineDebugScreen extends ConsumerWidget {
  const TrainingEngineDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineAsync = ref.watch(trainingEngineProvider);
    final readinessAsync = ref.watch(readinessProvider);
    final fatigueRowsAsync = ref.watch(engineDebugFatigueRowsProvider);
    final recommendationRowsAsync = ref.watch(
      engineDebugRecommendationRowsProvider,
    );
    final heatmapAsync = ref.watch(engineHeatmapDataProvider);
    final persistedStateAsync = ref.watch(
      engineDebugPersistedStateSummaryProvider,
    );
    final rawSnapshotAsync = ref.watch(engineDebugRawSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Engine Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset & Re-bootstrap Engine',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset Engine State'),
                  content: const Text(
                    'This will clear the persisted training engine state and '
                    'rebuild from workout history. ACWR history will reset.\n\n'
                    'Continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await resetAndRebootstrapEngine(ref);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            engineAsync.when(
              loading: _loadingCard,
              error: (error, stack) =>
                  _ErrorSectionCard(title: 'Engine Status', error: error),
              data: (engine) => _EngineStatusCard(engine: engine),
            ),
            const SizedBox(height: 16),
            readinessAsync.when(
              loading: _loadingCard,
              error: (error, stack) =>
                  _ErrorSectionCard(title: 'Readiness Breakdown', error: error),
              data: (readiness) => _ReadinessCard(readiness: readiness),
            ),
            const SizedBox(height: 16),
            fatigueRowsAsync.when(
              loading: _loadingCard,
              error: (error, stack) =>
                  _ErrorSectionCard(title: 'Fatigue Breakdown', error: error),
              data: (rows) => heatmapAsync.when(
                loading: () => _FatigueCard(rows: rows),
                error: (error, stack) =>
                    _FatigueCard(rows: rows, heatmapError: error),
                data: (heatmapData) =>
                    _FatigueCard(rows: rows, heatmapData: heatmapData),
              ),
            ),
            const SizedBox(height: 16),
            recommendationRowsAsync.when(
              loading: _loadingCard,
              error: (error, stack) => _ErrorSectionCard(
                title: 'Recommendation Breakdown',
                error: error,
              ),
              data: (rows) => _RecommendationCard(rows: rows),
            ),
            const SizedBox(height: 16),
            persistedStateAsync.when(
              loading: _loadingCard,
              error: (error, stack) => _ErrorSectionCard(
                title: 'Persisted State Summary',
                error: error,
              ),
              data: (summary) => _PersistedStateCard(summary: summary),
            ),
            const SizedBox(height: 16),
            rawSnapshotAsync.when(
              loading: _loadingCard,
              error: (error, stack) =>
                  _ErrorSectionCard(title: 'Raw Snapshot', error: error),
              data: (snapshot) => _RawSnapshotCard(snapshot: snapshot),
            ),
          ],
        ),
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

class _FatigueCard extends StatelessWidget {
  const _FatigueCard({required this.rows, this.heatmapData, this.heatmapError});

  final List<EngineDebugFatigueRow> rows;
  final Map<Muscle, MuscleData>? heatmapData;
  final Object? heatmapError;

  @override
  Widget build(BuildContext context) {
    final heatmapEntries = heatmapData?.entries.toList();
    heatmapEntries?.sort((a, b) => a.key.name.compareTo(b.key.name));

    return _SectionCard(
      title: 'Fatigue Breakdown',
      children: [
        if (rows.isEmpty)
          const Text(
            'No fatigue rows available yet. Ingested strength sessions will populate this section.',
          )
        else
          ...rows.map(
            (row) => _KvRow(
              label: row.muscleId,
              value:
                  '${row.status.phase.name} • ${row.value.toStringAsFixed(1)}',
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Heatmap Payload',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (heatmapError != null)
          Text('Heatmap unavailable: $heatmapError')
        else if (heatmapEntries == null || heatmapEntries.isEmpty)
          const Text('No heatmap data available.')
        else
          ...heatmapEntries.map(
            (entry) => _KvRow(
              label: entry.key.name,
              value: 'intensity ${entry.value.intensity.toStringAsFixed(2)}',
            ),
          ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rows});

  final List<EngineDebugRecommendationRow> rows;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recommendation Breakdown',
      children: [
        if (rows.isEmpty)
          const Text(
            'No recommendation rows available yet. Ingested strength sessions will populate this section.',
          )
        else
          ...rows.expand((row) {
            final children = <Widget>[
              Text(
                row.exerciseName,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _KvRow(
                label: 'e1RM',
                value: row.e1rm == null
                    ? 'Unavailable'
                    : '${row.e1rm!.toStringAsFixed(1)} kg',
              ),
              _KvRow(
                label: 'Last top set',
                value: _formatLoggedSet(row.lastTopSet),
              ),
              _KvRow(
                label: 'Suggested weight',
                value: row.recommendation.suggestedWeightKg == null
                    ? 'Unavailable'
                    : '${row.recommendation.suggestedWeightKg!.toStringAsFixed(1)} kg',
              ),
              const SizedBox(height: 4),
              Text(
                'Explanation',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(row.recommendation.explanation),
            ];

            return <Widget>[
              ...children,
              if (row != rows.last) const Divider(height: 24),
            ];
          }),
      ],
    );
  }
}

class _PersistedStateCard extends StatelessWidget {
  const _PersistedStateCard({required this.summary});

  final EngineDebugPersistedStateSummary summary;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Persisted State Summary',
      children: [
        _KvRow(label: 'ACWR state', value: summary.acwrSummary),
        _KvRow(label: 'Daily loads', value: summary.dailyLoadsCount.toString()),
        _KvRow(
          label: 'Last top sets',
          value: summary.lastTopSetsCount.toString(),
        ),
        _KvRow(
          label: 'e1RM history',
          value: summary.e1rmHistoryCount.toString(),
        ),
        const SizedBox(height: 8),
        if (summary.latestDailyLoad != null) ...[
          Text(
            'Latest Daily Load',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _KvRow(label: 'Date', value: summary.latestDailyLoad!.date),
          _KvRow(label: 'Volume', value: summary.latestDailyLoad!.volume),
        ],
        if (summary.lastTopSetRows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Last Top Set Exercises',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...summary.lastTopSetRows.map(
            (entry) => _KvRow(label: entry.label, value: entry.value),
          ),
        ],
        if (summary.e1rmHistoryRows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'e1RM History Exercises',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...summary.e1rmHistoryRows.map(
            (entry) =>
                _KvRow(label: entry.label, value: '${entry.count} estimates'),
          ),
        ],
      ],
    );
  }
}

class _RawSnapshotCard extends StatelessWidget {
  const _RawSnapshotCard({required this.snapshot});

  final String snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(
          'Raw Snapshot',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              snapshot,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatLoggedSet(LoggedSet? set) {
  if (set == null) return 'Unavailable';
  return '${set.weightKg.toStringAsFixed(1)} kg × ${set.reps} @ ${set.rpe.toStringAsFixed(1)}';
}

class _ErrorSectionCard extends StatelessWidget {
  const _ErrorSectionCard({required this.title, required this.error});

  final String title;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      children: [
        Text(
          'Debug data unavailable: ${error.toString()}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
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
