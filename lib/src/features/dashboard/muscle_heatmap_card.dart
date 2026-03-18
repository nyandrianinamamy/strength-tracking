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
                        height: 240,
                        child: CustomPaint(
                          painter: _BodyPainter(
                            fatigue: fatigue,
                            isFront: true,
                          ),
                          size: Size.infinite,
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
                      SizedBox(
                        height: 240,
                        child: CustomPaint(
                          painter: _BodyPainter(
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
    required this.fatigue,
    required this.isFront,
  });

  final Map<String, double> fatigue;
  final bool isFront;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final basePaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    // Draw the full body outline first as a smooth silhouette
    _drawSilhouette(canvas, cx, w, h, basePaint);

    // Draw colored muscle overlays
    if (isFront) {
      _drawFrontMuscles(canvas, cx, w, h);
    } else {
      _drawBackMuscles(canvas, cx, w, h);
    }
  }

  void _drawSilhouette(Canvas canvas, double cx, double w, double h, Paint paint) {
    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.06), width: w * 0.20, height: h * 0.09),
      paint,
    );

    // Neck
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.12), width: w * 0.10, height: h * 0.04),
      paint,
    );

    // Torso — use path for tapered shape (wider at shoulders, narrower at waist)
    final torso = Path()
      ..moveTo(cx - w * 0.22, h * 0.14) // left shoulder
      ..quadraticBezierTo(cx - w * 0.24, h * 0.18, cx - w * 0.22, h * 0.25) // chest curve
      ..lineTo(cx - w * 0.18, h * 0.38) // taper to waist
      ..quadraticBezierTo(cx - w * 0.16, h * 0.42, cx - w * 0.17, h * 0.46) // hip curve
      ..lineTo(cx + w * 0.17, h * 0.46) // across hip
      ..quadraticBezierTo(cx + w * 0.16, h * 0.42, cx + w * 0.18, h * 0.38) // hip curve
      ..lineTo(cx + w * 0.22, h * 0.25) // taper from waist
      ..quadraticBezierTo(cx + w * 0.24, h * 0.18, cx + w * 0.22, h * 0.14) // chest curve
      ..close();
    canvas.drawPath(torso, paint);

    // Shoulders — rounded caps
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.24, h * 0.15), width: w * 0.10, height: h * 0.05),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.24, h * 0.15), width: w * 0.10, height: h * 0.05),
      paint,
    );

    // Upper arms
    _drawLimb(canvas, paint, cx - w * 0.28, h * 0.17, cx - w * 0.32, h * 0.32, w * 0.08);
    _drawLimb(canvas, paint, cx + w * 0.28, h * 0.17, cx + w * 0.32, h * 0.32, w * 0.08);

    // Forearms
    _drawLimb(canvas, paint, cx - w * 0.32, h * 0.32, cx - w * 0.34, h * 0.46, w * 0.065);
    _drawLimb(canvas, paint, cx + w * 0.32, h * 0.32, cx + w * 0.34, h * 0.46, w * 0.065);

    // Hands
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.35, h * 0.49), width: w * 0.055, height: h * 0.035),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.35, h * 0.49), width: w * 0.055, height: h * 0.035),
      paint,
    );

    // Upper legs (thighs) — tapered
    _drawLimb(canvas, paint, cx - w * 0.13, h * 0.46, cx - w * 0.14, h * 0.68, w * 0.13);
    _drawLimb(canvas, paint, cx + w * 0.13, h * 0.46, cx + w * 0.14, h * 0.68, w * 0.13);

    // Lower legs (calves) — tapered thinner
    _drawLimb(canvas, paint, cx - w * 0.14, h * 0.68, cx - w * 0.14, h * 0.88, w * 0.10);
    _drawLimb(canvas, paint, cx + w * 0.14, h * 0.68, cx + w * 0.14, h * 0.88, w * 0.10);

    // Feet
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.14, h * 0.92), width: w * 0.09, height: h * 0.035),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.14, h * 0.92), width: w * 0.09, height: h * 0.035),
      paint,
    );
  }

  /// Draw a tapered limb between two points
  void _drawLimb(Canvas canvas, Paint paint, double x1, double y1, double x2, double y2, double thickness) {
    final path = Path();
    // Perpendicular offset for thickness
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len = (dx * dx + dy * dy);
    final nx = -dy / (len == 0 ? 1 : _sqrt(len));
    final ny = dx / (len == 0 ? 1 : _sqrt(len));

    final t1 = thickness / 2;
    final t2 = thickness / 2.5; // taper at the end

    path.moveTo(x1 + nx * t1, y1 + ny * t1);
    path.quadraticBezierTo(
      (x1 + x2) / 2 + nx * t1 * 1.1,
      (y1 + y2) / 2 + ny * t1 * 1.1,
      x2 + nx * t2,
      y2 + ny * t2,
    );
    path.lineTo(x2 - nx * t2, y2 - ny * t2);
    path.quadraticBezierTo(
      (x1 + x2) / 2 - nx * t1 * 1.1,
      (y1 + y2) / 2 - ny * t1 * 1.1,
      x1 - nx * t1,
      y1 - ny * t1,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  double _sqrt(double v) {
    // Simple Newton's method sqrt
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 10; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  void _drawFrontMuscles(Canvas canvas, double cx, double w, double h) {
    // Shoulders — rounded ovals on each side
    _paintOval(canvas, 'Shoulders', cx - w * 0.24, h * 0.15, w * 0.10, h * 0.05);
    _paintOval(canvas, 'Shoulders', cx + w * 0.24, h * 0.15, w * 0.10, h * 0.05);

    // Chest — two pec shapes
    _paintOval(canvas, 'Chest', cx - w * 0.10, h * 0.22, w * 0.18, h * 0.08);
    _paintOval(canvas, 'Chest', cx + w * 0.10, h * 0.22, w * 0.18, h * 0.08);

    // Biceps — ovals on inner arms
    _paintOval(canvas, 'Biceps', cx - w * 0.28, h * 0.25, w * 0.07, h * 0.09);
    _paintOval(canvas, 'Biceps', cx + w * 0.28, h * 0.25, w * 0.07, h * 0.09);

    // Abs — series of small rounded shapes
    for (int i = 0; i < 3; i++) {
      final y = h * (0.32 + i * 0.045);
      _paintOval(canvas, 'Abs', cx - w * 0.05, y, w * 0.08, h * 0.035);
      _paintOval(canvas, 'Abs', cx + w * 0.05, y, w * 0.08, h * 0.035);
    }

    // Quads — large ovals on front thighs
    _paintOval(canvas, 'Quads', cx - w * 0.13, h * 0.56, w * 0.11, h * 0.14);
    _paintOval(canvas, 'Quads', cx + w * 0.13, h * 0.56, w * 0.11, h * 0.14);
  }

  void _drawBackMuscles(Canvas canvas, double cx, double w, double h) {
    // Upper Back / Traps — wide across upper back
    _paintOval(canvas, 'Upper Back', cx, h * 0.17, w * 0.28, h * 0.07);

    // Lats — two wing shapes
    _paintOval(canvas, 'Lats', cx - w * 0.12, h * 0.28, w * 0.14, h * 0.10);
    _paintOval(canvas, 'Lats', cx + w * 0.12, h * 0.28, w * 0.14, h * 0.10);

    // Triceps — ovals on back of arms
    _paintOval(canvas, 'Triceps', cx - w * 0.29, h * 0.25, w * 0.07, h * 0.09);
    _paintOval(canvas, 'Triceps', cx + w * 0.29, h * 0.25, w * 0.07, h * 0.09);

    // Glutes — two rounded shapes
    _paintOval(canvas, 'Glutes', cx - w * 0.10, h * 0.45, w * 0.14, h * 0.07);
    _paintOval(canvas, 'Glutes', cx + w * 0.10, h * 0.45, w * 0.14, h * 0.07);

    // Hamstrings — back of thighs
    _paintOval(canvas, 'Hamstrings', cx - w * 0.13, h * 0.57, w * 0.10, h * 0.13);
    _paintOval(canvas, 'Hamstrings', cx + w * 0.13, h * 0.57, w * 0.10, h * 0.13);
  }

  void _paintOval(Canvas canvas, String muscle, double cx, double cy, double rw, double rh) {
    final value = fatigue[muscle] ?? 0.0;
    final paint = Paint()
      ..color = _fatigueColor(value)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rw, height: rh),
      paint,
    );
  }

  Color _fatigueColor(double value) {
    if (value <= 0.0) return Colors.grey.shade300;
    if (value <= 0.2) {
      return Color.lerp(Colors.grey.shade300, Colors.blue.shade300, value / 0.2)!;
    }
    if (value <= 0.4) {
      return Color.lerp(Colors.blue.shade300, Colors.green.shade400, (value - 0.2) / 0.2)!;
    }
    if (value <= 0.6) {
      return Color.lerp(Colors.green.shade400, Colors.yellow.shade600, (value - 0.4) / 0.2)!;
    }
    if (value <= 0.8) {
      return Color.lerp(Colors.yellow.shade600, Colors.orange.shade600, (value - 0.6) / 0.2)!;
    }
    return Color.lerp(Colors.orange.shade600, Colors.red.shade500, (value - 0.8) / 0.2)!;
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) {
    return oldDelegate.fatigue != fatigue;
  }
}
