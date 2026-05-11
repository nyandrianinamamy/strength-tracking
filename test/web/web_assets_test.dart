import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web manifest', () {
    test('identifies Kotrana and avoids stale product wording', () {
      final manifest = _readJsonMap('web/manifest.json');

      expect(manifest['name'], contains('Kotrana'));
      expect(manifest['short_name'], 'Kotrana');
      expect(manifest['description'], contains('Kotrana'));
      expect(manifest['start_url'], isNotEmpty);
      expect(manifest['display'], 'standalone');

      final manifestText = _readText('web/manifest.json');
      _expectNoStaleProductWording(manifestText);
    });

    test('includes installable icon files', () {
      final manifest = _readJsonMap('web/manifest.json');
      final icons = (manifest['icons'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(icons, isNotEmpty);
      expect(icons.any((icon) => icon['sizes'] == '192x192'), isTrue);
      expect(icons.any((icon) => icon['sizes'] == '512x512'), isTrue);
      expect(
        icons.any((icon) => '${icon['purpose']}'.contains('maskable')),
        isTrue,
      );

      for (final icon in icons) {
        expect(icon['type'], 'image/png');
        final src = icon['src'] as String?;
        expect(src, isNotNull);
        expect(
          File('web/$src').existsSync(),
          isTrue,
          reason: 'Missing web/$src',
        );
      }
    });
  });

  group('web index', () {
    test('links the manifest and exposes Kotrana PWA metadata', () {
      final indexHtml = _readText('web/index.html');

      expect(indexHtml, contains('<link rel="manifest" href="manifest.json">'));
      expect(
        indexHtml,
        contains('<link rel="apple-touch-icon" href="icons/Icon-192.png">'),
      );
      expect(
        indexHtml,
        contains(
          '<meta name="application-name" content="Kotrana: Musculation">',
        ),
      );
      expect(
        indexHtml,
        contains('<meta name="apple-mobile-web-app-title" content="Kotrana">'),
      );
      expect(indexHtml, contains('<title>Kotrana: Musculation</title>'));
      expect(File('web/favicon.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-192.png').existsSync(), isTrue);

      _expectNoStaleProductWording(indexHtml);
    });
  });

  group('static legal pages', () {
    test('privacy page matches supported HealthKit read behavior', () {
      final privacyHtml = _readText('web/privacy.html');

      expect(privacyHtml, contains('<title>Kotrana Privacy Policy</title>'));
      expect(privacyHtml, contains('<h1>Kotrana Privacy Policy</h1>'));
      expect(
        privacyHtml,
        contains('may read sleep, heart rate variability, resting heart rate'),
      );
      expect(
        privacyHtml,
        contains(
          'We do not use HealthKit data for advertising, marketing, or data mining.',
        ),
      );
      expect(privacyHtml, isNot(matches(_unsupportedHealthKitWriteClaim)));

      _expectNoStaleProductWording(privacyHtml);
    });

    test('terms page keeps HealthKit claims read-only and optional', () {
      final termsHtml = _readText('web/terms.html');

      expect(termsHtml, contains('<title>Kotrana Terms of Use</title>'));
      expect(termsHtml, contains('<h1>Kotrana Terms of Use</h1>'));
      expect(termsHtml, contains('Apple Health integration is optional.'));
      expect(
        termsHtml,
        contains('Health data is used to provide app features'),
      );
      expect(termsHtml, isNot(matches(_unsupportedHealthKitWriteClaim)));

      _expectNoStaleProductWording(termsHtml);
    });
  });

  group('feature inventory', () {
    test('web claims are backed by the asset and legal-link tests', () {
      final inventory = _readText('docs/app-feature-inventory.md');

      expect(inventory, contains('PWA manifest at `web/manifest.json`'));
      expect(
        inventory,
        contains(
          'Static privacy and terms pages at `web/privacy.html` and `web/terms.html`',
        ),
      );
      expect(inventory, contains('test/web/web_assets_test.dart'));
      expect(inventory, contains('test/core/legal_links_test.dart'));
    });
  });
}

final _unsupportedHealthKitWriteClaim = RegExp(
  r'HealthKit[^.]*\bwrite\b|\bwrite\b[^.]*HealthKit|\bwrite\b[^.]*workout',
  caseSensitive: false,
);

Map<String, dynamic> _readJsonMap(String path) {
  final decoded = jsonDecode(_readText(path));
  expect(decoded, isA<Map<String, dynamic>>());
  return decoded as Map<String, dynamic>;
}

String _readText(String path) => File(path).readAsStringSync();

void _expectNoStaleProductWording(String text) {
  expect(text, isNot(contains('StrengthApp')));
  expect(text, isNot(contains('Strength Training Tracker')));
  expect(text, isNot(contains('strength_training_tracker')));
}
