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
                        _sideLabel('FRONT'),
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
                        _sideLabel('BACK'),
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
                        _sideLabel('FRONT'),
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
                        _sideLabel('BACK'),
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

// These labels describe the test fixture; BodyHeatmap paints no text. Keep
// them accessible without introducing platform font rasterization into the
// golden, and retain the 17px label slot so the body geometry stays unchanged.
Widget _sideLabel(String label) => Semantics(
  label: label,
  child: const SizedBox(height: 17, width: double.infinity),
);
