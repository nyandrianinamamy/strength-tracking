import 'dart:io';

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
}
