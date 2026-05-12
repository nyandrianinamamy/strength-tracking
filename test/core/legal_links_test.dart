import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/legal_links.dart';

void main() {
  test('legal links default to public HTTPS pages', () {
    expect(kotranaPrivacyPolicyUrl.scheme, 'https');
    expect(kotranaTermsUrl.scheme, 'https');
    expect(kotranaPrivacyPolicyUrl.path, endsWith('/privacy.html'));
    expect(kotranaTermsUrl.path, endsWith('/terms.html'));
  });

  test('legal links resolve to the web legal asset destinations', () {
    expect(
      kotranaPrivacyPolicyUrl.toString(),
      'https://myappv4.web.app/privacy.html',
    );
    expect(kotranaTermsUrl.toString(), 'https://myappv4.web.app/terms.html');
  });

  test('legal links are absolute URLs', () {
    expect(kotranaPrivacyPolicyUrl.hasAbsolutePath, isTrue);
    expect(kotranaTermsUrl.hasAbsolutePath, isTrue);
  });
}
