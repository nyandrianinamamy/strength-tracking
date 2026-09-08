import 'external_url_opener_platform.dart';

class ExternalUrlOpener {
  const ExternalUrlOpener();

  Future<void> open(Uri url) => openExternalUrl(url);
}
