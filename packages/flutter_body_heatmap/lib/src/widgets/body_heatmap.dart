import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/body_part_data.dart';
import '../data/female_back.dart';
import '../data/female_front.dart';
import '../data/male_back.dart';
import '../data/male_front.dart';
import '../data/outlines.dart';
import '../muscle.dart';
import '../svg_path_parser.dart';
import '../types.dart';

/// A widget that displays a human body with highlightable muscle regions.
class BodyHeatmap extends StatelessWidget {
  const BodyHeatmap({
    super.key,
    this.side = BodySide.front,
    this.gender = BodyGender.male,
    this.data = const {},
    this.colors = const [Color(0xFF74b9ff), Color(0xFF0984e3)],
    this.bodyColor = const Color(0xFF3F3F3F),
    this.borderColor = const Color(0xFFDFDFDF),
    this.showBorder = true,
    this.onMusclePressed,
  });

  /// Front or back view.
  final BodySide side;

  /// Male or female body shape.
  final BodyGender gender;

  /// Muscle highlight data. Key is Muscle enum, value is MuscleData.
  final Map<Muscle, MuscleData> data;

  /// Color scale for intensity-based coloring.
  /// Index 0 = lowest intensity, last index = highest intensity.
  /// For continuous values, colors are interpolated.
  final List<Color> colors;

  /// Default body/muscle color when not highlighted.
  final Color bodyColor;

  /// Border/outline color.
  final Color borderColor;

  /// Whether to show the body outline border.
  final bool showBorder;

  /// Callback when a muscle region is pressed.
  final void Function(Muscle muscle, MuscleSide side)? onMusclePressed;

  @override
  Widget build(BuildContext context) {
    if (onMusclePressed != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) =>
                _handleTap(details.localPosition, constraints.biggest),
            child: CustomPaint(
              painter: _BodyHeatmapPainter(
                side: side,
                gender: gender,
                data: data,
                colors: colors,
                bodyColor: bodyColor,
                borderColor: borderColor,
                showBorder: showBorder,
              ),
              size: Size.infinite,
            ),
          );
        },
      );
    }
    return CustomPaint(
      painter: _BodyHeatmapPainter(
        side: side,
        gender: gender,
        data: data,
        colors: colors,
        bodyColor: bodyColor,
        borderColor: borderColor,
        showBorder: showBorder,
      ),
      size: Size.infinite,
    );
  }

  void _handleTap(Offset position, Size size) {
    final parts = _getBodyParts();
    final viewBoxX = _getViewBoxX();
    const viewBoxW = 724.0;
    const viewBoxH = 1448.0;

    final scaleX = size.width / viewBoxW;
    final scaleY = size.height / viewBoxH;
    final scale = math.min(scaleX, scaleY);

    final drawW = viewBoxW * scale;
    final drawH = viewBoxH * scale;
    final oX = (size.width - drawW) / 2;
    final oY = (size.height - drawH) / 2;

    // Convert tap position to SVG coordinates
    final svgX = (position.dx - oX) / scale + viewBoxX;
    final svgY = (position.dy - oY) / scale;

    for (final part in parts.reversed) {
      final muscle = Muscle.fromSlug(part.slug);
      if (muscle == null) continue;

      // Check left paths
      for (final d in part.leftPaths) {
        final path = parseSvgPath(d);
        if (path.contains(Offset(svgX, svgY))) {
          onMusclePressed?.call(muscle, MuscleSide.left);
          return;
        }
      }
      // Check right paths
      for (final d in part.rightPaths) {
        final path = parseSvgPath(d);
        if (path.contains(Offset(svgX, svgY))) {
          onMusclePressed?.call(muscle, MuscleSide.right);
          return;
        }
      }
      // Check common paths
      for (final d in part.commonPaths) {
        final path = parseSvgPath(d);
        if (path.contains(Offset(svgX, svgY))) {
          onMusclePressed?.call(muscle, MuscleSide.both);
          return;
        }
      }
    }
  }

  double _getViewBoxX() {
    if (gender == BodyGender.female) {
      return side == BodySide.front ? -50.0 : 756.0;
    }
    return side == BodySide.front ? 0.0 : 724.0;
  }

  List<BodyPartData> _getBodyParts() {
    if (gender == BodyGender.female) {
      return side == BodySide.front ? femaleFrontParts : femaleBackParts;
    }
    return side == BodySide.front ? maleFrontParts : maleBackParts;
  }
}

class _BodyHeatmapPainter extends CustomPainter {
  _BodyHeatmapPainter({
    required this.side,
    required this.gender,
    required this.data,
    required this.colors,
    required this.bodyColor,
    required this.borderColor,
    required this.showBorder,
  });

  final BodySide side;
  final BodyGender gender;
  final Map<Muscle, MuscleData> data;
  final List<Color> colors;
  final Color bodyColor;
  final Color borderColor;
  final bool showBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final parts = _getBodyParts();
    final outline = _getOutline();

    // ViewBox dimensions
    // Male front: 0 0 724 1448, back: 724 0 724 1448
    // Female front: -50 -40 734 1538, back: 756 0 774 1448
    final viewBoxX = _getViewBoxX();
    final viewBoxY = _getViewBoxY();
    final viewBoxW = _getViewBoxW();
    final viewBoxH = _getViewBoxH();

    final scaleX = size.width / viewBoxW;
    final scaleY = size.height / viewBoxH;
    final scale = math.min(scaleX, scaleY);

    // Center the drawing
    final drawW = viewBoxW * scale;
    final drawH = viewBoxH * scale;
    final offsetX = (size.width - drawW) / 2;
    final offsetY = (size.height - drawH) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);

    // Draw body parts
    for (final part in parts) {
      final muscle = Muscle.fromSlug(part.slug);
      final muscleData = muscle != null ? data[muscle] : null;

      final fillColor = _getColor(muscleData);

      // Draw common paths
      final commonPaint =
          Paint()
            ..style = PaintingStyle.fill
            ..color = fillColor;
      for (final d in part.commonPaths) {
        final path = parseSvgPath(
          d,
          scaleX: scale,
          scaleY: scale,
          offsetX: -viewBoxX,
          offsetY: -viewBoxY,
        );
        canvas.drawPath(path, commonPaint);
      }

      // Draw left paths
      final leftColor =
          (muscleData?.side == MuscleSide.right) ? bodyColor : fillColor;
      final leftPaint =
          Paint()
            ..style = PaintingStyle.fill
            ..color = leftColor;
      for (final d in part.leftPaths) {
        final path = parseSvgPath(
          d,
          scaleX: scale,
          scaleY: scale,
          offsetX: -viewBoxX,
          offsetY: -viewBoxY,
        );
        canvas.drawPath(path, leftPaint);
      }

      // Draw right paths
      final rightColor =
          (muscleData?.side == MuscleSide.left) ? bodyColor : fillColor;
      final rightPaint =
          Paint()
            ..style = PaintingStyle.fill
            ..color = rightColor;
      for (final d in part.rightPaths) {
        final path = parseSvgPath(
          d,
          scaleX: scale,
          scaleY: scale,
          offsetX: -viewBoxX,
          offsetY: -viewBoxY,
        );
        canvas.drawPath(path, rightPaint);
      }
    }

    // Draw outline
    if (showBorder && outline.isNotEmpty) {
      final outlinePaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..color = borderColor
            ..strokeWidth = 2.0;
      final outlinePath = parseSvgPath(
        outline,
        scaleX: scale,
        scaleY: scale,
        offsetX: -viewBoxX,
        offsetY: -viewBoxY,
      );
      canvas.drawPath(outlinePath, outlinePaint);
    }

    canvas.restore();
  }

  Color _getColor(MuscleData? muscleData) {
    if (muscleData == null) return bodyColor;
    if (muscleData.color != null) return muscleData.color!;
    if (muscleData.intensity <= 0) return bodyColor;

    if (colors.isEmpty) return bodyColor;
    if (colors.length == 1) return colors[0];

    // Interpolate: intensity 0..1 maps across the color list
    final t = muscleData.intensity.clamp(0.0, 1.0);
    final maxIdx = colors.length - 1;
    final idx = t * maxIdx;
    final lower = idx.floor().clamp(0, maxIdx);
    final upper = idx.ceil().clamp(0, maxIdx);
    final frac = idx - lower;

    return Color.lerp(colors[lower], colors[upper], frac) ?? colors[0];
  }

  double _getViewBoxX() {
    if (gender == BodyGender.female) {
      return side == BodySide.front ? -50.0 : 756.0;
    }
    return side == BodySide.front ? 0.0 : 724.0;
  }

  double _getViewBoxY() {
    if (gender == BodyGender.female) {
      return side == BodySide.front ? -40.0 : 0.0;
    }
    return 0.0;
  }

  double _getViewBoxW() {
    if (gender == BodyGender.female) {
      return side == BodySide.front ? 734.0 : 774.0;
    }
    return 724.0;
  }

  double _getViewBoxH() {
    if (gender == BodyGender.female) {
      return side == BodySide.front ? 1538.0 : 1448.0;
    }
    return 1448.0;
  }

  List<BodyPartData> _getBodyParts() {
    if (gender == BodyGender.female) {
      return side == BodySide.front ? femaleFrontParts : femaleBackParts;
    }
    return side == BodySide.front ? maleFrontParts : maleBackParts;
  }

  String _getOutline() {
    if (gender == BodyGender.female) {
      return side == BodySide.front ? femaleFrontOutline : femaleBackOutline;
    }
    return side == BodySide.front ? maleFrontOutline : maleBackOutline;
  }

  @override
  bool shouldRepaint(covariant _BodyHeatmapPainter old) {
    return old.data != data ||
        old.side != side ||
        old.gender != gender ||
        old.bodyColor != bodyColor ||
        old.colors != colors ||
        old.borderColor != borderColor ||
        old.showBorder != showBorder;
  }
}
