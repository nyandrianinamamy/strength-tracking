import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('static legal pages', () {
    test('support page gives App Store users a contact path', () {
      final supportHtml = _readText('site/support.html');

      expect(supportHtml, contains('<title>Kotrana Support</title>'));
      expect(supportHtml, contains('<h1>Kotrana Support</h1>'));
      expect(supportHtml, contains('nyandrianinamamy@gmail.com'));
      expect(supportHtml, contains('href="/privacy"'));
      expect(supportHtml, contains('href="/terms"'));

      _expectNoStaleProductWording(supportHtml);
    });

    test('privacy page describes optional Health reads', () {
      final privacyHtml = _readText('site/privacy.html');

      expect(privacyHtml, contains('<title>Kotrana Privacy Policy</title>'));
      expect(privacyHtml, contains('<h1>Kotrana Privacy Policy</h1>'));
      expect(
        privacyHtml,
        contains('may read sleep, heart rate variability, resting heart rate'),
      );
      expect(privacyHtml, contains('invite-only'));
      expect(privacyHtml, contains('email address'));
      expect(
        privacyHtml,
        contains(
          'We do not use HealthKit data for advertising, marketing, or data mining.',
        ),
      );

      _expectNoStaleProductWording(privacyHtml);
    });

    test(
      'terms page keeps HealthKit optional and describes the supported apps',
      () {
        final termsHtml = _readText('site/terms.html');

        expect(termsHtml, contains('<title>Kotrana Terms of Use</title>'));
        expect(termsHtml, contains('<h1>Kotrana Terms of Use</h1>'));
        expect(termsHtml, contains('Apple Health integration is optional.'));
        expect(
          termsHtml,
          contains('Health data is used to provide app features'),
        );
        expect(termsHtml, contains('for iPhone and Apple Watch.'));

        _expectNoStaleProductWording(termsHtml);
      },
    );
  });
}

String _readText(String path) => File(path).readAsStringSync();

void _expectNoStaleProductWording(String text) {
  expect(text, isNot(contains('StrengthApp')));
  expect(text, isNot(contains('Strength Training Tracker')));
  expect(text, isNot(contains('strength_training_tracker')));
}
