import 'package:web/web.dart' as web;

Future<void> openExternalUrl(Uri url) async {
  if (!url.hasScheme) {
    throw ArgumentError.value(url, 'url', 'Expected an absolute URL');
  }

  web.window.open(url.toString(), '_blank');
}
