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

  test('TestFlight workflow maps tag suffix to build number', () {
    final workflow = File('.github/workflows/build-ios.yml').readAsStringSync();
    final fastfile = File('ios/fastlane/Fastfile').readAsStringSync();

    expect(workflow, contains(r'VERSION="${TAG%%+*}"'));
    expect(workflow, contains(r'BUILD="${TAG#*+}"'));
    expect(
      workflow,
      contains(r'BUILD_VERSION: ${{ steps.version.outputs.version }}'),
    );
    expect(
      workflow,
      contains(r'BUILD_NUMBER: ${{ steps.version.outputs.build }}'),
    );
    expect(workflow, contains('flutter-version: 3.41.9'));

    expect(fastfile, contains('"FLUTTER_BUILD_NAME" => ENV["BUILD_VERSION"]'));
    expect(fastfile, contains('"FLUTTER_BUILD_NUMBER" => ENV["BUILD_NUMBER"]'));
    expect(fastfile, contains('xcargs: version_settings'));
    expect(fastfile, isNot(contains('increment_version_number')));
    expect(fastfile, isNot(contains('increment_build_number')));
  });

  test('all embedded target configurations inherit Flutter version settings', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final companion = File('ios/Flutter/Companion.xcconfig').readAsStringSync();
    expect(companion, contains('#include "Generated.xcconfig"'));
    expect(companion, contains(r'MARKETING_VERSION = $(FLUTTER_BUILD_NAME)'));
    expect(
      companion,
      contains(r'CURRENT_PROJECT_VERSION = $(FLUTTER_BUILD_NUMBER)'),
    );

    final reference = RegExp(
      r'(\w+) /\* Companion.xcconfig \*/ = \{isa = PBXFileReference;[^\n]*path = Flutter/Companion.xcconfig;',
    ).firstMatch(project);
    expect(
      reference,
      isNotNull,
      reason: 'The base config must resolve to the shared file',
    );
    final referenceId = reference!.group(1)!;
    final configurations = RegExp(
      r'\t\t\w+ /\* (Debug|Release|Profile) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;([\s\S]*?)\n\t\t\};',
    ).allMatches(project);
    for (final suffix in ['watchkitapp', 'liveactivity']) {
      final targetConfigurations = configurations
          .where(
            (match) => match
                .group(2)!
                .contains(
                  'PRODUCT_BUNDLE_IDENTIFIER = "dev.mamy-r.kotrana.$suffix";',
                ),
          )
          .toList();
      expect(
        targetConfigurations.map((match) => match.group(1)),
        unorderedEquals(['Debug', 'Release', 'Profile']),
      );
      for (final configuration in targetConfigurations) {
        final settings = configuration.group(2)!;
        expect(
          settings,
          contains(
            'baseConfigurationReference = $referenceId /* Companion.xcconfig */;',
          ),
        );
        expect(
          settings,
          isNot(contains('MARKETING_VERSION =')),
          reason: '$suffix must not override the shared marketing version',
        );
        expect(
          settings,
          isNot(contains('CURRENT_PROJECT_VERSION =')),
          reason: '$suffix must not override the shared build number',
        );
      }
    }
  });

  test('source bundle plists preserve their version placeholders', () {
    final runner = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      runner,
      contains(
        '<key>CFBundleShortVersionString</key>\n\t<string>\$(FLUTTER_BUILD_NAME)</string>',
      ),
    );
    expect(
      runner,
      contains(
        '<key>CFBundleVersion</key>\n\t<string>\$(FLUTTER_BUILD_NUMBER)</string>',
      ),
    );
    for (final path in [
      'ios/StrengthAppWatch Watch App/Info.plist',
      'ios/StrengthAppLiveActivity-Info.plist',
    ]) {
      final info = File(path).readAsStringSync();
      expect(
        info,
        contains(
          '<key>CFBundleShortVersionString</key>\n\t<string>\$(MARKETING_VERSION)</string>',
        ),
        reason: path,
      );
      expect(
        info,
        contains(
          '<key>CFBundleVersion</key>\n\t<string>\$(CURRENT_PROJECT_VERSION)</string>',
        ),
        reason: path,
      );
    }
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

  test(
    'prepared App Store screenshots include iPhone and Apple Watch PNGs',
    () {
      final screenshotDir = Directory('ios/fastlane/screenshots/en-US');
      final screenshots =
          screenshotDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.png'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final iPhoneScreenshots = screenshots
          .where((file) => file.uri.pathSegments.last.endsWith('_6_9.png'))
          .toList();
      expect(iPhoneScreenshots.map((file) => file.uri.pathSegments.last), [
        '01_dashboard_6_9.png',
        '02_routines_6_9.png',
        '03_progress_6_9.png',
        '04_exercises_6_9.png',
        '05_heatmap_6_9.png',
      ]);
      for (final screenshot in iPhoneScreenshots) {
        final dimensions = _readPngDimensions(screenshot);
        expect(dimensions.width, 1290, reason: screenshot.path);
        expect(dimensions.height, 2796, reason: screenshot.path);
      }

      final watchScreenshots = screenshots
          .where((file) => file.uri.pathSegments.last.endsWith('_45mm.png'))
          .toList();
      expect(watchScreenshots.map((file) => file.uri.pathSegments.last), [
        '01_watch_45mm.png',
      ]);
      for (final screenshot in watchScreenshots) {
        final dimensions = _readPngDimensions(screenshot);
        expect(dimensions.width, 396, reason: screenshot.path);
        expect(dimensions.height, 484, reason: screenshot.path);
      }
    },
  );
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
