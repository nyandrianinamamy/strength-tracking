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
                          gender: state.bodyGender == 'female' ? BodyGender.female : BodyGender.male,
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
                          gender: state.bodyGender == 'female' ? BodyGender.female : BodyGender.male,
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
}
