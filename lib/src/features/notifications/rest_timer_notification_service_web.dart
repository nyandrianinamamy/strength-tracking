import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class RestTimerNotificationService {
  Timer? _pendingTimer;

  Future<void> primePermission() async {
    if (!_isSupported) return;
    if (web.Notification.permission == 'default') {
      await web.Notification.requestPermission().toDart;
    }
  }

  String _notificationTitle = '';
  String _notificationBody = '';

  void scheduleRestEnd({
    required Duration duration,
    required String exerciseName,
    required String notificationTitle,
    required String notificationBody,
  }) {
    cancel();
    if (!_isSupported || duration <= Duration.zero) {
      return;
    }

    _notificationTitle = notificationTitle;
    _notificationBody = notificationBody;

    _pendingTimer = Timer(duration, () {
      unawaited(_showRestCompleteNotification(
        title: _notificationTitle,
        body: _notificationBody,
      ));
    });
  }

  void cancel() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  bool get _isSupported => true;

  Future<void> _showRestCompleteNotification({
    required String title,
    required String body,
  }) async {
    if (!_isSupported || web.Notification.permission != 'granted') {
      return;
    }

    if (web.document.visibilityState == 'visible') {
      return;
    }

    final options = web.NotificationOptions(
      body: body,
      tag: 'strengthapp-rest-timer',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-maskable-192.png',
      requireInteraction: true,
    );

    try {
      final registration = await web.window.navigator.serviceWorker.ready.toDart;
      await registration.showNotification(title, options).toDart;
    } catch (_) {
      web.Notification(title, options);
    }
  }
}
