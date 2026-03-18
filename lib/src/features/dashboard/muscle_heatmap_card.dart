import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_service.dart';

class MuscleHeatmapCard extends ConsumerWidget {
  const MuscleHeatmapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateControllerProvider);
    final fatigue =
        ref.read(muscleHeatmapServiceProvider).computeFatigue(state);

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
                      SizedBox(
                        height: 220,
                        child: CustomPaint(
                          painter: _BodyPainter(
                            muscles: MuscleHeatmapService.frontMuscles,
                            fatigue: fatigue,
                            isFront: true,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Text('BACK', style: _labelStyle(context)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: CustomPaint(
                          painter: _BodyPainter(
                            muscles: MuscleHeatmapService.backMuscles,
                            fatigue: fatigue,
                            isFront: false,
                          ),
                          size: Size.infinite,
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
        Text(
          'Recovered',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.slateInactive,
                fontSize: 10,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade300,
                  Colors.blue.shade300,
                  Colors.green.shade400,
                  Colors.yellow.shade600,
                  Colors.orange.shade600,
                  Colors.red.shade500,
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Fatigued',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.slateInactive,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.muscles,
    required this.fatigue,
    required this.isFront,
  });

  final List<String> muscles;
  final Map<String, double> fatigue;
  final bool isFront;

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    // Draw base body silhouette
    _drawBodyOutline(canvas, size, outlinePaint);

    // Draw colored muscle regions on top
    if (isFront) {
      _drawFrontMuscles(canvas, size);
    } else {
      _drawBackMuscles(canvas, size);
    }
  }

  void _drawBodyOutline(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Head
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.08),
        width: w * 0.18,
        height: h * 0.1,
      ),
      paint,
    );
    // Neck
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, h * 0.15),
        width: w * 0.08,
        height: h * 0.04,
      ),
      paint,
    );
    // Torso
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.33),
          width: w * 0.4,
          height: h * 0.32,
        ),
        const Radius.circular(8),
      ),
      paint,
    );
    // Left arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.28, h * 0.30),
          width: w * 0.1,
          height: h * 0.28,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
    // Right arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.28, h * 0.30),
          width: w * 0.1,
          height: h * 0.28,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
    // Left leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.12, h * 0.68),
          width: w * 0.14,
          height: h * 0.35,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
    // Right leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.12, h * 0.68),
          width: w * 0.14,
          height: h * 0.35,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
    // Left forearm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.32, h * 0.50),
          width: w * 0.08,
          height: h * 0.18,
        ),
        const Radius.circular(4),
      ),
      paint,
    );
    // Right forearm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.32, h * 0.50),
          width: w * 0.08,
          height: h * 0.18,
        ),
        const Radius.circular(4),
      ),
      paint,
    );
    // Left shin
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.12, h * 0.88),
          width: w * 0.11,
          height: h * 0.18,
        ),
        const Radius.circular(4),
      ),
      paint,
    );
    // Right shin
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.12, h * 0.88),
          width: w * 0.11,
          height: h * 0.18,
        ),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  void _drawFrontMuscles(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Chest
    _drawMuscle(
      canvas,
      'Chest',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.25),
          width: w * 0.35,
          height: h * 0.12,
        ),
        const Radius.circular(6),
      ),
    );

    // Shoulders (two parts)
    _drawMuscle(
      canvas,
      'Shoulders',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.22, h * 0.20),
          width: w * 0.1,
          height: h * 0.07,
        ),
        const Radius.circular(4),
      ),
    );
    _drawMuscle(
      canvas,
      'Shoulders',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.22, h * 0.20),
          width: w * 0.1,
          height: h * 0.07,
        ),
        const Radius.circular(4),
      ),
    );

    // Biceps
    _drawMuscle(
      canvas,
      'Biceps',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.27, h * 0.30),
          width: w * 0.08,
          height: h * 0.12,
        ),
        const Radius.circular(4),
      ),
    );
    _drawMuscle(
      canvas,
      'Biceps',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.27, h * 0.30),
          width: w * 0.08,
          height: h * 0.12,
        ),
        const Radius.circular(4),
      ),
    );

    // Abs
    _drawMuscle(
      canvas,
      'Abs',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.40),
          width: w * 0.22,
          height: h * 0.14,
        ),
        const Radius.circular(6),
      ),
    );

    // Quads
    _drawMuscle(
      canvas,
      'Quads',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.12, h * 0.62),
          width: w * 0.13,
          height: h * 0.18,
        ),
        const Radius.circular(6),
      ),
    );
    _drawMuscle(
      canvas,
      'Quads',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.12, h * 0.62),
          width: w * 0.13,
          height: h * 0.18,
        ),
        const Radius.circular(6),
      ),
    );
  }

  void _drawBackMuscles(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Upper Back / Traps
    _drawMuscle(
      canvas,
      'Upper Back',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.22),
          width: w * 0.32,
          height: h * 0.1,
        ),
        const Radius.circular(6),
      ),
    );

    // Lats
    _drawMuscle(
      canvas,
      'Lats',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.34),
          width: w * 0.36,
          height: h * 0.12,
        ),
        const Radius.circular(6),
      ),
    );

    // Triceps
    _drawMuscle(
      canvas,
      'Triceps',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.27, h * 0.30),
          width: w * 0.08,
          height: h * 0.12,
        ),
        const Radius.circular(4),
      ),
    );
    _drawMuscle(
      canvas,
      'Triceps',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.27, h * 0.30),
          width: w * 0.08,
          height: h * 0.12,
        ),
        const Radius.circular(4),
      ),
    );

    // Glutes
    _drawMuscle(
      canvas,
      'Glutes',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.49),
          width: w * 0.32,
          height: h * 0.1,
        ),
        const Radius.circular(6),
      ),
    );

    // Hamstrings
    _drawMuscle(
      canvas,
      'Hamstrings',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - w * 0.12, h * 0.62),
          width: w * 0.13,
          height: h * 0.18,
        ),
        const Radius.circular(6),
      ),
    );
    _drawMuscle(
      canvas,
      'Hamstrings',
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + w * 0.12, h * 0.62),
          width: w * 0.13,
          height: h * 0.18,
        ),
        const Radius.circular(6),
      ),
    );
  }

  void _drawMuscle(Canvas canvas, String muscle, RRect rrect) {
    final value = fatigue[muscle] ?? 0.0;
    final paint = Paint()
      ..color = _fatigueColor(value)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paint);
  }

  Color _fatigueColor(double value) {
    if (value <= 0.0) return Colors.grey.shade300;
    if (value <= 0.2) {
      return Color.lerp(
          Colors.grey.shade300, Colors.blue.shade300, value / 0.2)!;
    }
    if (value <= 0.4) {
      return Color.lerp(
          Colors.blue.shade300, Colors.green.shade400, (value - 0.2) / 0.2)!;
    }
    if (value <= 0.6) {
      return Color.lerp(
          Colors.green.shade400, Colors.yellow.shade600, (value - 0.4) / 0.2)!;
    }
    if (value <= 0.8) {
      return Color.lerp(
          Colors.yellow.shade600, Colors.orange.shade600, (value - 0.6) / 0.2)!;
    }
    return Color.lerp(
        Colors.orange.shade600, Colors.red.shade500, (value - 0.8) / 0.2)!;
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) {
    return oldDelegate.fatigue != fatigue;
  }
}
