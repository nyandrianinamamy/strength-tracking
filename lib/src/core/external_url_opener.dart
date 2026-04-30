import 'external_url_opener_platform.dart'
    if (dart.library.js_interop) 'external_url_opener_web.dart';

class ExternalUrlOpener {
  const ExternalUrlOpener();

  Future<void> open(Uri url) => openExternalUrl(url);
}
