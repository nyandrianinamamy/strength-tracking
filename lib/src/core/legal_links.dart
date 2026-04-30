const String _defaultLegalBaseUrl = 'https://myappv4.web.app';

const String _privacyPolicyUrl = String.fromEnvironment(
  'KOTRANA_PRIVACY_URL',
  defaultValue: '$_defaultLegalBaseUrl/privacy.html',
);

const String _termsUrl = String.fromEnvironment(
  'KOTRANA_TERMS_URL',
  defaultValue: '$_defaultLegalBaseUrl/terms.html',
);

final Uri kotranaPrivacyPolicyUrl = Uri.parse(_privacyPolicyUrl);
final Uri kotranaTermsUrl = Uri.parse(_termsUrl);
