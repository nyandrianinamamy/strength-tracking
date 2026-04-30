import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('dev.mamy_r.kotrana/url_opener');

Future<void> openExternalUrl(Uri url) async {
  if (!url.hasScheme) {
    throw ArgumentError.value(url, 'url', 'Expected an absolute URL');
  }

  final opened = await _channel.invokeMethod<bool>('openUrl', <String, String>{
    'url': url.toString(),
  });

  if (opened != true) {
    throw StateError('Could not open $url');
  }
}
