import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Runner embeds the Watch app in normal builds', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final phaseStart = project.indexOf('/* Embed Watch Content */ = {');
    expect(phaseStart, isNonNegative);

    final phaseEnd = project.indexOf('\n\t\t};', phaseStart);
    expect(phaseEnd, isNonNegative);

    final phase = project.substring(phaseStart, phaseEnd);
    expect(
      phase,
      contains('StrengthAppWatch Watch App.app in Embed Watch Content'),
    );
    expect(phase, contains('runOnlyForDeploymentPostprocessing = 0;'));
  });
}
