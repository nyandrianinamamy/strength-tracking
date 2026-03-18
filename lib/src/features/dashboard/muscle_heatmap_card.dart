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
                      AspectRatio(
                        aspectRatio: 0.42,
                        child: CustomPaint(
                          painter: _BodyPainter(fatigue: fatigue, isFront: true),
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
                      AspectRatio(
                        aspectRatio: 0.42,
                        child: CustomPaint(
                          painter: _BodyPainter(fatigue: fatigue, isFront: false),
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
              gradient: LinearGradient(colors: [
                Colors.grey.shade300,
                Colors.blue.shade300,
                Colors.green.shade400,
                Colors.yellow.shade600,
                Colors.orange.shade600,
                Colors.red.shade500,
              ]),
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

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.fatigue, required this.isFront});

  final Map<String, double> fatigue;
  final bool isFront;

  // All coordinates are expressed as fractions of (w, h) so the drawing
  // scales to any size.

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw the full-body silhouette as one smooth outline
    _drawBodySilhouette(canvas, w, h);

    // 2. Paint muscle regions on top
    if (isFront) {
      _frontMuscles(canvas, w, h);
    } else {
      _backMuscles(canvas, w, h);
    }
  }

  // ----- body silhouette (continuous path) -----

  void _drawBodySilhouette(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    // Head
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.055),
            width: w * 0.22,
            height: h * 0.085),
        paint);

    // Neck
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.105),
            width: w * 0.11,
            height: h * 0.03),
        paint);

    // Torso — single smooth path
    final torso = Path()
      ..moveTo(w * 0.28, h * 0.11) // left neck base
      ..cubicTo(w * 0.18, h * 0.12, w * 0.18, h * 0.14,
          w * 0.22, h * 0.16) // left shoulder curve
      ..cubicTo(w * 0.26, h * 0.18, w * 0.26, h * 0.28,
          w * 0.27, h * 0.32) // left chest/side
      ..cubicTo(w * 0.27, h * 0.36, w * 0.26, h * 0.40,
          w * 0.28, h * 0.42) // waist taper
      ..cubicTo(w * 0.30, h * 0.44, w * 0.32, h * 0.46,
          w * 0.34, h * 0.47) // left hip
      ..lineTo(w * 0.66, h * 0.47) // across hips
      ..cubicTo(w * 0.68, h * 0.46, w * 0.70, h * 0.44,
          w * 0.72, h * 0.42) // right hip
      ..cubicTo(w * 0.74, h * 0.40, w * 0.73, h * 0.36,
          w * 0.73, h * 0.32) // right waist
      ..cubicTo(w * 0.74, h * 0.28, w * 0.74, h * 0.18,
          w * 0.78, h * 0.16) // right chest/side
      ..cubicTo(w * 0.82, h * 0.14, w * 0.82, h * 0.12,
          w * 0.72, h * 0.11) // right shoulder
      ..close();
    canvas.drawPath(torso, paint);

    // Left upper arm
    _drawArmPath(canvas, paint, w, h,
        shoulderX: 0.22, shoulderY: 0.16, elbowX: 0.14, elbowY: 0.34,
        thickness: 0.065, taperFactor: 0.8);
    // Right upper arm
    _drawArmPath(canvas, paint, w, h,
        shoulderX: 0.78, shoulderY: 0.16, elbowX: 0.86, elbowY: 0.34,
        thickness: 0.065, taperFactor: 0.8);

    // Left forearm
    _drawArmPath(canvas, paint, w, h,
        shoulderX: 0.14, shoulderY: 0.34, elbowX: 0.11, elbowY: 0.48,
        thickness: 0.05, taperFactor: 0.7);
    // Right forearm
    _drawArmPath(canvas, paint, w, h,
        shoulderX: 0.86, shoulderY: 0.34, elbowX: 0.89, elbowY: 0.48,
        thickness: 0.05, taperFactor: 0.7);

    // Hands
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.10, h * 0.50),
            width: w * 0.045,
            height: h * 0.025),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.90, h * 0.50),
            width: w * 0.045,
            height: h * 0.025),
        paint);

    // Left thigh
    _drawLegPath(canvas, paint, w, h,
        hipX: 0.39, hipY: 0.47, kneeX: 0.37, kneeY: 0.68,
        thickness: 0.09, taperFactor: 0.7);
    // Right thigh
    _drawLegPath(canvas, paint, w, h,
        hipX: 0.61, hipY: 0.47, kneeX: 0.63, kneeY: 0.68,
        thickness: 0.09, taperFactor: 0.7);

    // Left calf
    _drawLegPath(canvas, paint, w, h,
        hipX: 0.37, hipY: 0.68, kneeX: 0.36, kneeY: 0.88,
        thickness: 0.065, taperFactor: 0.6);
    // Right calf
    _drawLegPath(canvas, paint, w, h,
        hipX: 0.63, hipY: 0.68, kneeX: 0.64, kneeY: 0.88,
        thickness: 0.065, taperFactor: 0.6);

    // Feet
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.36, h * 0.91),
            width: w * 0.07,
            height: h * 0.025),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.64, h * 0.91),
            width: w * 0.07,
            height: h * 0.025),
        paint);
  }

  void _drawArmPath(Canvas canvas, Paint paint, double w, double h, {
    required double shoulderX, required double shoulderY,
    required double elbowX, required double elbowY,
    required double thickness, required double taperFactor,
  }) {
    final t1 = w * thickness / 2;
    final t2 = t1 * taperFactor;
    final sx = w * shoulderX;
    final sy = h * shoulderY;
    final ex = w * elbowX;
    final ey = h * elbowY;

    final path = Path()
      ..moveTo(sx - t1, sy)
      ..quadraticBezierTo((sx + ex) / 2 - t1 * 1.05, (sy + ey) / 2, ex - t2, ey)
      ..lineTo(ex + t2, ey)
      ..quadraticBezierTo((sx + ex) / 2 + t1 * 1.05, (sy + ey) / 2, sx + t1, sy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawLegPath(Canvas canvas, Paint paint, double w, double h, {
    required double hipX, required double hipY,
    required double kneeX, required double kneeY,
    required double thickness, required double taperFactor,
  }) {
    final t1 = w * thickness / 2;
    final t2 = t1 * taperFactor;
    final hx = w * hipX;
    final hy = h * hipY;
    final kx = w * kneeX;
    final ky = h * kneeY;

    final path = Path()
      ..moveTo(hx - t1, hy)
      ..cubicTo(hx - t1 * 1.1, hy + (ky - hy) * 0.4,
          kx - t2 * 1.05, ky - (ky - hy) * 0.2, kx - t2, ky)
      ..lineTo(kx + t2, ky)
      ..cubicTo(kx + t2 * 1.05, ky - (ky - hy) * 0.2,
          hx + t1 * 1.1, hy + (ky - hy) * 0.4, hx + t1, hy)
      ..close();
    canvas.drawPath(path, paint);
  }

  // ----- muscle overlays (smooth ovals) -----

  void _frontMuscles(Canvas canvas, double w, double h) {
    // Shoulders
    _muscle(canvas, 'Shoulders', w * 0.24, h * 0.155, w * 0.10, h * 0.04);
    _muscle(canvas, 'Shoulders', w * 0.76, h * 0.155, w * 0.10, h * 0.04);

    // Chest — two pecs
    _muscle(canvas, 'Chest', w * 0.39, h * 0.21, w * 0.16, h * 0.06);
    _muscle(canvas, 'Chest', w * 0.61, h * 0.21, w * 0.16, h * 0.06);

    // Biceps
    _muscle(canvas, 'Biceps', w * 0.18, h * 0.25, w * 0.055, h * 0.07);
    _muscle(canvas, 'Biceps', w * 0.82, h * 0.25, w * 0.055, h * 0.07);

    // Abs — 6-pack pattern
    for (int i = 0; i < 3; i++) {
      final y = h * (0.29 + i * 0.04);
      _muscle(canvas, 'Abs', w * 0.46, y, w * 0.06, h * 0.03);
      _muscle(canvas, 'Abs', w * 0.54, y, w * 0.06, h * 0.03);
    }

    // Quads
    _muscle(canvas, 'Quads', w * 0.40, h * 0.56, w * 0.08, h * 0.11);
    _muscle(canvas, 'Quads', w * 0.60, h * 0.56, w * 0.08, h * 0.11);
  }

  void _backMuscles(Canvas canvas, double w, double h) {
    // Traps / Upper back
    _muscle(canvas, 'Upper Back', w * 0.50, h * 0.17, w * 0.24, h * 0.055);

    // Lats
    _muscle(canvas, 'Lats', w * 0.40, h * 0.27, w * 0.11, h * 0.08);
    _muscle(canvas, 'Lats', w * 0.60, h * 0.27, w * 0.11, h * 0.08);

    // Triceps
    _muscle(canvas, 'Triceps', w * 0.83, h * 0.25, w * 0.05, h * 0.07);
    _muscle(canvas, 'Triceps', w * 0.17, h * 0.25, w * 0.05, h * 0.07);

    // Glutes
    _muscle(canvas, 'Glutes', w * 0.43, h * 0.44, w * 0.11, h * 0.055);
    _muscle(canvas, 'Glutes', w * 0.57, h * 0.44, w * 0.11, h * 0.055);

    // Hamstrings
    _muscle(canvas, 'Hamstrings', w * 0.40, h * 0.57, w * 0.07, h * 0.10);
    _muscle(canvas, 'Hamstrings', w * 0.60, h * 0.57, w * 0.07, h * 0.10);
  }

  void _muscle(Canvas canvas, String name, double cx, double cy, double rw, double rh) {
    final v = fatigue[name] ?? 0.0;
    final paint = Paint()
      ..color = _color(v)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rw, height: rh),
        paint);
  }

  Color _color(double v) {
    if (v <= 0.0) return Colors.grey.shade300;
    if (v <= 0.2) return Color.lerp(Colors.grey.shade300, Colors.blue.shade300, v / 0.2)!;
    if (v <= 0.4) return Color.lerp(Colors.blue.shade300, Colors.green.shade400, (v - 0.2) / 0.2)!;
    if (v <= 0.6) return Color.lerp(Colors.green.shade400, Colors.yellow.shade600, (v - 0.4) / 0.2)!;
    if (v <= 0.8) return Color.lerp(Colors.yellow.shade600, Colors.orange.shade600, (v - 0.6) / 0.2)!;
    return Color.lerp(Colors.orange.shade600, Colors.red.shade500, (v - 0.8) / 0.2)!;
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) => old.fatigue != fatigue;
}
