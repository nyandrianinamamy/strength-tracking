import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/legal_links.dart';

void main() {
  test('legal links default to public HTTPS pages', () {
    expect(kotranaPrivacyPolicyUrl.scheme, 'https');
    expect(kotranaTermsUrl.scheme, 'https');
    expect(kotranaSupportUrl.scheme, 'https');
    expect(kotranaPrivacyPolicyUrl.path, '/privacy');
    expect(kotranaTermsUrl.path, '/terms');
    expect(kotranaSupportUrl.path, '/support');
  });

  test('legal links resolve to the web legal asset destinations', () {
    expect(
      kotranaPrivacyPolicyUrl.toString(),
      'https://kotrana.mamy-r.dev/privacy',
    );
    expect(kotranaTermsUrl.toString(), 'https://kotrana.mamy-r.dev/terms');
    expect(kotranaSupportUrl.toString(), 'https://kotrana.mamy-r.dev/support');
  });

  test('legal links are absolute URLs', () {
    expect(kotranaPrivacyPolicyUrl.hasAbsolutePath, isTrue);
    expect(kotranaTermsUrl.hasAbsolutePath, isTrue);
    expect(kotranaSupportUrl.hasAbsolutePath, isTrue);
  });
}
