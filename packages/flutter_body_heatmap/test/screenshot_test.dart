import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';

void main() {
  testWidgets('male front screenshot', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 300,
              height: 600,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _caption('FRONT'),
                        const SizedBox(height: 8),
                        Expanded(
                          child: BodyHeatmap(
                            side: BodySide.front,
                            gender: BodyGender.male,
                            data: const {
                              Muscle.chest: MuscleData(intensity: 0.9),
                              Muscle.deltoids: MuscleData(intensity: 0.7),
                              Muscle.biceps: MuscleData(intensity: 0.6),
                              Muscle.abs: MuscleData(intensity: 0.4),
                              Muscle.obliques: MuscleData(intensity: 0.3),
                              Muscle.quadriceps: MuscleData(intensity: 0.5),
                              Muscle.trapezius: MuscleData(intensity: 0.2),
                            },
                            colors: const [
                              Color(0xFFE2E8F0),
                              Color(0xFF93C5FD),
                              Color(0xFF4ADE80),
                              Color(0xFFFBBF24),
                              Color(0xFFF97316),
                              Color(0xFFEF4444),
                            ],
                            bodyColor: const Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _caption('BACK'),
                        const SizedBox(height: 8),
                        Expanded(
                          child: BodyHeatmap(
                            side: BodySide.back,
                            gender: BodyGender.male,
                            data: const {
                              Muscle.upperBack: MuscleData(intensity: 0.8),
                              Muscle.trapezius: MuscleData(intensity: 0.6),
                              Muscle.triceps: MuscleData(intensity: 0.5),
                              Muscle.gluteal: MuscleData(intensity: 0.7),
                              Muscle.hamstring: MuscleData(intensity: 0.4),
                              Muscle.calves: MuscleData(intensity: 0.3),
                              Muscle.lowerBack: MuscleData(intensity: 0.2),
                            },
                            colors: const [
                              Color(0xFFE2E8F0),
                              Color(0xFF93C5FD),
                              Color(0xFF4ADE80),
                              Color(0xFFFBBF24),
                              Color(0xFFF97316),
                              Color(0xFFEF4444),
                            ],
                            bodyColor: const Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('FRONT'), findsOneWidget);
    expect(find.bySemanticsLabel('BACK'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('screenshots/male_heatmap.png'),
    );
  });

  testWidgets('female front screenshot', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 300,
              height: 600,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _caption('FRONT'),
                        const SizedBox(height: 8),
                        Expanded(
                          child: BodyHeatmap(
                            side: BodySide.front,
                            gender: BodyGender.female,
                            data: const {
                              Muscle.chest: MuscleData(intensity: 0.5),
                              Muscle.deltoids: MuscleData(intensity: 0.8),
                              Muscle.biceps: MuscleData(intensity: 0.4),
                              Muscle.abs: MuscleData(intensity: 0.6),
                              Muscle.quadriceps: MuscleData(intensity: 0.9),
                              Muscle.adductors: MuscleData(intensity: 0.3),
                            },
                            colors: const [
                              Color(0xFFE2E8F0),
                              Color(0xFF93C5FD),
                              Color(0xFF4ADE80),
                              Color(0xFFFBBF24),
                              Color(0xFFF97316),
                              Color(0xFFEF4444),
                            ],
                            bodyColor: const Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _caption('BACK'),
                        const SizedBox(height: 8),
                        Expanded(
                          child: BodyHeatmap(
                            side: BodySide.back,
                            gender: BodyGender.female,
                            data: const {
                              Muscle.upperBack: MuscleData(intensity: 0.6),
                              Muscle.trapezius: MuscleData(intensity: 0.4),
                              Muscle.gluteal: MuscleData(intensity: 0.9),
                              Muscle.hamstring: MuscleData(intensity: 0.7),
                              Muscle.calves: MuscleData(intensity: 0.5),
                            },
                            colors: const [
                              Color(0xFFE2E8F0),
                              Color(0xFF93C5FD),
                              Color(0xFF4ADE80),
                              Color(0xFFFBBF24),
                              Color(0xFFF97316),
                              Color(0xFFEF4444),
                            ],
                            bodyColor: const Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('FRONT'), findsOneWidget);
    expect(find.bySemanticsLabel('BACK'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('screenshots/female_heatmap.png'),
    );
  });
}

// Ahem only supplies regular weight. Synthetic bold and inherited Material line
// height can rasterize differently across macOS versions. Keep the original
// 17px caption slot so the body images stay fixed, and place regular glyphs on
// integer pixels inside it (10px Ahem has an 8px ascent and 2px descent).
// Four pixels of letter spacing preserve the original 70px/56px label widths.
Widget _caption(String label) => SizedBox(
  height: 17,
  child: Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Text(
      label,
      style: const TextStyle(
        inherit: false,
        color: Color(0xFF1D1B20),
        fontFamily: 'Ahem',
        fontWeight: FontWeight.w400,
        fontSize: 10,
        height: 1,
        letterSpacing: 4,
      ),
    ),
  ),
);
