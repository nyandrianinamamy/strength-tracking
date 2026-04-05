import 'package:flutter/material.dart';
import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';

class MuscleHeatmapCard extends ConsumerWidget {
  const MuscleHeatmapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateControllerProvider);
    final fatigue = ref.watch(engineHeatmapDataProvider).maybeWhen(
      data: (data) => data,
      orElse: () => const <Muscle, MuscleData>{},
    );
    final l10n = AppLocalizations.of(context)!;
    final appColors = context.appColors;
    final heatmapColors = appColors.heatmapGradient;

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
                          Text(l10n.front, style: _labelStyle(context)),
                          const SizedBox(height: 8),
                          AspectRatio(
                            aspectRatio: 0.5,
                            child: BodyHeatmap(
                              side: BodySide.front,
                              gender: state.sex == 'female'
                                  ? BodyGender.female
                                  : BodyGender.male,
                              data: fatigue,
                              colors: heatmapColors,
                              bodyColor: appColors.heatmapBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Text(l10n.back, style: _labelStyle(context)),
                          const SizedBox(height: 8),
                          AspectRatio(
                            aspectRatio: 0.5,
                            child: BodyHeatmap(
                              side: BodySide.back,
                              gender: state.sex == 'female'
                                  ? BodyGender.female
                                  : BodyGender.male,
                              data: fatigue,
                              colors: heatmapColors,
                              bodyColor: appColors.heatmapBody,
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
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: appColors.subtleText,
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
          color: context.appColors.subtleText,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        );
  }

  Widget _buildLegend(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = context.appColors;
    return Row(
      children: [
        Text(l10n.recovered,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: appColors.subtleText,
                  fontSize: 10,
                )),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: appColors.heatmapGradient),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(l10n.fatigued,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: appColors.subtleText,
                  fontSize: 10,
                )),
      ],
    );
  }

  void _showHeatmapInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appColors = context.appColors;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
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
                    color: appColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.muscleFatigueMap,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.heatmapDescription,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: appColors.subtleText,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.howItWorks,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _infoRow(sheetContext, Icons.fitness_center, l10n.heatmapVolume),
              const SizedBox(height: 6),
              _infoRow(sheetContext, Icons.timer_outlined, l10n.heatmapDecay),
              const SizedBox(height: 6),
              _infoRow(sheetContext, Icons.palette_outlined, l10n.heatmapColors),
              const SizedBox(height: 6),
              _infoRow(sheetContext, Icons.group_work_outlined, l10n.heatmapSecondary),
              const SizedBox(height: 16),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(colors: appColors.heatmapGradient),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.recovered,
                      style: TextStyle(fontSize: 11, color: appColors.subtleText)),
                  Text(l10n.fatigued,
                      style: TextStyle(fontSize: 11, color: appColors.subtleText)),
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
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.subtleText,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}
