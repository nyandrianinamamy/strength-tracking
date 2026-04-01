import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.subtleText,
    required this.border,
    required this.surfaceMuted,
    required this.ink,
    required this.warning,
    required this.onWarning,
    required this.heatmapGradient,
    required this.heatmapBody,
  });

  final Color subtleText;
  final Color border;
  final Color surfaceMuted;
  final Color ink;
  final Color warning;
  final Color onWarning;
  final List<Color> heatmapGradient;
  final Color heatmapBody;

  static const light = AppColors(
    subtleText: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    surfaceMuted: Color(0xFFF1F5F9),
    ink: Color(0xFF0F172A),
    warning: Color(0xFFF57C00),       // orange.shade700
    onWarning: Colors.white,
    heatmapGradient: [
      Color(0xFFE0E0E0), // grey.shade300
      Color(0xFF90CAF9), // blue.shade300
      Color(0xFF66BB6A), // green.shade400
      Color(0xFFFDD835), // yellow.shade600
      Color(0xFFFB8C00), // orange.shade600
      Color(0xFFEF5350), // red.shade500
    ],
    heatmapBody: Color(0xFFE2E8F0),
  );

  static const dark = AppColors(
    subtleText: Color(0xFF9CA3AF),
    border: Color(0xFF333350),
    surfaceMuted: Color(0xFF2A2A45),
    ink: Colors.white,
    warning: Color(0xFFFFA726),       // orange.shade400
    onWarning: Colors.white,
    heatmapGradient: [
      Color(0xFF757575), // grey.shade600
      Color(0xFF42A5F5), // blue.shade400
      Color(0xFF66BB6A), // green.shade300
      Color(0xFFFFEE58), // yellow.shade500
      Color(0xFFFFA726), // orange.shade400
      Color(0xFFEF5350), // red.shade400
    ],
    heatmapBody: Color(0xFF4A4A6A),
  );

  @override
  AppColors copyWith({
    Color? subtleText,
    Color? border,
    Color? surfaceMuted,
    Color? ink,
    Color? warning,
    Color? onWarning,
    List<Color>? heatmapGradient,
    Color? heatmapBody,
  }) {
    return AppColors(
      subtleText: subtleText ?? this.subtleText,
      border: border ?? this.border,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      ink: ink ?? this.ink,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      heatmapGradient: heatmapGradient ?? this.heatmapGradient,
      heatmapBody: heatmapBody ?? this.heatmapBody,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      heatmapGradient: [
        for (int i = 0; i < heatmapGradient.length; i++)
          Color.lerp(heatmapGradient[i], other.heatmapGradient[i], t)!,
      ],
      heatmapBody: Color.lerp(heatmapBody, other.heatmapBody, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
