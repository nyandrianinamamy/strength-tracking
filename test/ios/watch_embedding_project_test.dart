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
    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = "dev\.mamy-r\.kotrana\.watchkitapp";'
        r'[\s\S]*?SUPPORTED_PLATFORMS = "watchos watchsimulator";',
      ).allMatches(project),
      hasLength(3),
    );
  });

  test('WatchSessionManager waits for activation and cleans payloads', () {
    final manager = File('ios/WatchSessionManager.swift').readAsStringSync();

    expect(manager, contains('pendingOutboundMessage'));
    expect(manager, contains('session.activationState == .activated'));
    expect(manager, contains('flushPendingOutboundMessage()'));
    expect(manager, contains('sanitizePropertyListValue'));
    expect(manager, contains('value is NSNull'));
  });

  test('Watch app is display-only and owns rest haptics globally', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final contentView = File(
      'ios/StrengthAppWatch Watch App/ContentView.swift',
    ).readAsStringSync();
    final exercisePage = File(
      'ios/StrengthAppWatch Watch App/Views/ExercisePageView.swift',
    ).readAsStringSync();
    final strengthView = File(
      'ios/StrengthAppWatch Watch App/Views/StrengthExerciseView.swift',
    ).readAsStringSync();
    final timedView = File(
      'ios/StrengthAppWatch Watch App/Views/TimedExerciseView.swift',
    ).readAsStringSync();
    final sessionModel = File(
      'ios/StrengthAppWatch Watch App/Models/SessionSnapshot.swift',
    ).readAsStringSync();
    final manager = File(
      'ios/StrengthAppWatch Watch App/WorkoutSessionManager.swift',
    ).readAsStringSync();
    final watchInfoPlist = File(
      'ios/StrengthAppWatch Watch App/Info.plist',
    ).readAsStringSync();

    expect(contentView, isNot(contains('LogSetMessage')));
    expect(exercisePage, isNot(contains('onLogSet')));
    expect(strengthView, isNot(contains('digitalCrownRotation')));
    expect(strengthView, isNot(contains('LOG SET')));
    expect(timedView, isNot(contains('Button(action: toggleTimer)')));
    expect(timedView, isNot(contains('onLogTimedSet')));
    expect(timedView, isNot(contains(r'\(targetDuration)s')));
    expect(timedView, contains('formatDurationLabel(targetDuration)'));

    expect(sessionModel, contains('WatchRestState'));
    expect(sessionModel, contains('activeRest'));
    expect(manager, contains('activeRestRemaining'));
    expect(manager, contains('configureActiveRest'));
    expect(manager, contains('restHapticTimer'));
    expect(watchInfoPlist, contains('<key>WKBackgroundModes</key>'));
    expect(project, contains('INFOPLIST_KEY_WKBackgroundModes'));
    expect(project, contains('membershipExceptions'));
    expect(project, contains('workout-processing'));
  });
}
