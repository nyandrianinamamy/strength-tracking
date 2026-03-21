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

  void scheduleRestEnd({
    required Duration duration,
    required String exerciseName,
  }) {
    cancel();
    if (!_isSupported || duration <= Duration.zero) {
      return;
    }

    _pendingTimer = Timer(duration, () {
      unawaited(_showRestCompleteNotification(exerciseName: exerciseName));
    });
  }

  void cancel() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  bool get _isSupported => true;

  Future<void> _showRestCompleteNotification({
    required String exerciseName,
  }) async {
    if (!_isSupported || web.Notification.permission != 'granted') {
      return;
    }

    if (web.document.visibilityState == 'visible') {
      return;
    }

    final options = web.NotificationOptions(
      body: 'Rest complete. Back to $exerciseName.',
      tag: 'strengthapp-rest-timer',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-maskable-192.png',
      requireInteraction: true,
    );

    try {
      final registration = await web.window.navigator.serviceWorker.ready.toDart;
      await registration.showNotification('Rest timer complete', options).toDart;
    } catch (_) {
      web.Notification('Rest timer complete', options);
    }
  }
}
