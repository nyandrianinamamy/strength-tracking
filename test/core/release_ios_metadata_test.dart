import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Runner entitlement keeps HealthKit but removes clinical/background access',
    () {
      final entitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();

      expect(entitlements, contains('com.apple.developer.healthkit'));
      expect(
        entitlements,
        isNot(contains('com.apple.developer.healthkit.access')),
      );
      expect(
        entitlements,
        isNot(contains('com.apple.developer.healthkit.background-delivery')),
      );
      expect(entitlements, contains('com.apple.developer.applesignin'));
    },
  );

  test(
    'Watch entitlement keeps HealthKit but removes clinical/background access',
    () {
      final entitlements = File(
        'ios/StrengthAppWatch Watch App/StrengthAppWatch Watch App.entitlements',
      ).readAsStringSync();

      expect(entitlements, contains('com.apple.developer.healthkit'));
      expect(
        entitlements,
        isNot(contains('com.apple.developer.healthkit.access')),
      );
      expect(
        entitlements,
        isNot(contains('com.apple.developer.healthkit.background-delivery')),
      );
    },
  );

  test('Runner Info.plist does not claim Bluetooth accessory access', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(info, isNot(contains('NSBluetoothAlwaysUsageDescription')));
  });

  test('Runner release target stays iPhone-only for prepared screenshots', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final runnerConfigPattern = RegExp(
      r'buildSettings = \{(?<settings>[\s\S]*?PRODUCT_BUNDLE_IDENTIFIER = "?dev\.mamy-r\.kotrana"?;[\s\S]*?)\};',
    );
    final runnerSettings = runnerConfigPattern
        .allMatches(project)
        .map((match) => match.namedGroup('settings')!)
        .toList();

    expect(runnerSettings, isNotEmpty);
    for (final settings in runnerSettings) {
      expect(settings, contains('TARGETED_DEVICE_FAMILY = 1;'));
      expect(settings, contains('SUPPORTS_MACCATALYST = NO;'));
      expect(settings, contains('SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;'));
      expect(settings, contains('SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;'));
    }
  });

  test('prepared App Store screenshots are iPhone 6.9-inch PNGs', () {
    final screenshotDir = Directory('ios/fastlane/screenshots/en-US');
    final screenshots =
        screenshotDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.png'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(screenshots.map((file) => file.uri.pathSegments.last), [
      '01_dashboard_6_9.png',
      '02_routines_6_9.png',
      '03_progress_6_9.png',
      '04_exercises_6_9.png',
      '05_heatmap_6_9.png',
    ]);
    for (final screenshot in screenshots) {
      final dimensions = _readPngDimensions(screenshot);
      expect(dimensions.width, 1290, reason: screenshot.path);
      expect(dimensions.height, 2796, reason: screenshot.path);
    }
  });
}

({int width, int height}) _readPngDimensions(File file) {
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24), reason: file.path);
  expect(bytes.sublist(0, 8), [
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
  ], reason: file.path);

  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (width: data.getUint32(16), height: data.getUint32(20));
}
