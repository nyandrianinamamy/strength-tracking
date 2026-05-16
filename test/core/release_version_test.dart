import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec version is bumped for the v1.0.31 release candidate', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version: 1\.0\.31\+(\d+)$', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(275));
  });
}
