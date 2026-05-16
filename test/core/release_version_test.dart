import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec version is bumped for the v1.0.31 release candidate', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec,
      contains(RegExp(r'^version: 1\.0\.31\+274$', multiLine: true)),
    );
  });
}
