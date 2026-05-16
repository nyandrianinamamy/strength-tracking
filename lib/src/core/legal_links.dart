const String _defaultLegalBaseUrl = 'https://kotrana.mamy-r.dev';

const String _privacyPolicyUrl = String.fromEnvironment(
  'KOTRANA_PRIVACY_URL',
  defaultValue: '$_defaultLegalBaseUrl/privacy',
);

const String _termsUrl = String.fromEnvironment(
  'KOTRANA_TERMS_URL',
  defaultValue: '$_defaultLegalBaseUrl/terms',
);

const String _supportUrl = String.fromEnvironment(
  'KOTRANA_SUPPORT_URL',
  defaultValue: '$_defaultLegalBaseUrl/support',
);

final Uri kotranaPrivacyPolicyUrl = Uri.parse(_privacyPolicyUrl);
final Uri kotranaTermsUrl = Uri.parse(_termsUrl);
final Uri kotranaSupportUrl = Uri.parse(_supportUrl);
