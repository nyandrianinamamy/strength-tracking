import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('light instance has expected subtleText', () {
      expect(AppColors.light.subtleText, const Color(0xFF94A3B8));
    });

    test('dark instance has expected subtleText', () {
      expect(AppColors.dark.subtleText, const Color(0xFF9CA3AF));
    });

    test('light and dark have different surfaceMuted', () {
      expect(AppColors.light.surfaceMuted, isNot(AppColors.dark.surfaceMuted));
    });

    test('heatmapGradient has 6 colors in both modes', () {
      expect(AppColors.light.heatmapGradient.length, 6);
      expect(AppColors.dark.heatmapGradient.length, 6);
    });

    test('copyWith preserves unchanged fields', () {
      final modified = AppColors.light.copyWith(
        warning: Colors.purple,
      );
      expect(modified.warning, Colors.purple);
      expect(modified.subtleText, AppColors.light.subtleText);
    });

    test('lerp interpolates between light and dark', () {
      final mid = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(mid.subtleText, isNot(AppColors.light.subtleText));
      expect(mid.subtleText, isNot(AppColors.dark.subtleText));
    });
  });

  group('AppColorsX extension', () {
    testWidgets('context.appColors returns light instance', (tester) async {
      late AppColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppColors.light]),
          home: Builder(builder: (context) {
            resolved = context.appColors;
            return const SizedBox();
          }),
        ),
      );
      expect(resolved.subtleText, AppColors.light.subtleText);
    });

    testWidgets('context.appColors returns dark instance', (tester) async {
      late AppColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            extensions: [AppColors.dark],
          ),
          themeMode: ThemeMode.dark,
          home: Builder(builder: (context) {
            resolved = context.appColors;
            return const SizedBox();
          }),
        ),
      );
      expect(resolved.subtleText, AppColors.dark.subtleText);
    });
  });
}
