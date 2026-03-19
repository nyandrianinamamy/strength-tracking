import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Clear service worker caches and reload on web
Future<void> forceUpdateApp() async {
  final cacheNames = await web.window.caches.keys().toDart;
  for (final name in cacheNames.toDart) {
    await web.window.caches.delete(name.toDart).toDart;
  }
  final registrations = await web.window.navigator.serviceWorker
      .getRegistrations()
      .toDart;
  for (final reg in registrations.toDart) {
    reg.unregister();
  }
  web.window.location.reload();
}
