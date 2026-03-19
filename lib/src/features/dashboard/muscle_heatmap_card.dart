import 'package:flutter/material.dart';
import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_service.dart';

class MuscleHeatmapCard extends ConsumerWidget {
  const MuscleHeatmapCard({super.key});

  static const _colors = [
    Color(0xFFE2E8F0), // gray (recovered)
    Color(0xFF93C5FD), // blue
    Color(0xFF4ADE80), // green
    Color(0xFFFBBF24), // yellow
    Color(0xFFF97316), // orange
    Color(0xFFEF4444), // red (fatigued)
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateControllerProvider);
    final fatigue = ref.read(muscleHeatmapServiceProvider).computeFatigue(state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('FRONT', style: _labelStyle(context)),
                          const SizedBox(height: 8),
                          AspectRatio(
                            aspectRatio: 0.5,
                            child: BodyHeatmap(
                              side: BodySide.front,
                              gender: state.bodyGender == 'female'
                                  ? BodyGender.female
                                  : BodyGender.male,
                              data: fatigue,
                              colors: _colors,
                              bodyColor: const Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Text('BACK', style: _labelStyle(context)),
                          const SizedBox(height: 8),
                          AspectRatio(
                            aspectRatio: 0.5,
                            child: BodyHeatmap(
                              side: BodySide.back,
                              gender: state.bodyGender == 'female'
                                  ? BodyGender.female
                                  : BodyGender.male,
                              data: fatigue,
                              colors: _colors,
                              bodyColor: const Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _showHeatmapInfo(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.slateInactive,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  TextStyle? _labelStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.slateInactive,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        );
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      children: [
        Text('Recovered',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.slateInactive,
                  fontSize: 10,
                )),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(colors: _colors),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('Fatigued',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.slateInactive,
                  fontSize: 10,
                )),
      ],
    );
  }

  void _showHeatmapInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Muscle Fatigue Map',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'This heatmap shows how much each muscle group has been trained recently.',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.slateInactive,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'How it works',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _infoRow(sheetContext, Icons.fitness_center, 'Volume is calculated from weight × reps for each set'),
              const SizedBox(height: 6),
              _infoRow(sheetContext, Icons.timer_outlined, 'Fatigue decays over time — contribution halves every 48 hours'),
              const SizedBox(height: 6),
              _infoRow(sheetContext, Icons.palette_outlined, 'Colors range from gray (recovered) to red (highly fatigued)'),
              const SizedBox(height: 6),
              _infoRow(sheetContext, Icons.group_work_outlined, 'Secondary muscles contribute at 50% of primary muscle weight'),
              const SizedBox(height: 16),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(colors: _colors),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recovered',
                      style: TextStyle(fontSize: 11, color: AppTheme.slateInactive)),
                  Text('Fatigued',
                      style: TextStyle(fontSize: 11, color: AppTheme.slateInactive)),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slateInactive,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}
