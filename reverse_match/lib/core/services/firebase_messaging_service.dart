import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/profile/data/profile_repository.dart';
import '../router/app_router.dart';
import '../storage/secure_storage_service.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(
    ref.read(profileRepositoryProvider),
    ref.read(secureStorageProvider),
  );
});

/// Top-level background handler — must be a top-level function, not a class method.
/// Register via FirebaseMessaging.onBackgroundMessage in main.dart.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.messageId}');
}

class FcmService {
  final ProfileRepository _profile;
  final SecureStorageService _storage;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  FcmService(this._profile, this._storage);

  /// Initialize FCM: request permissions, register token, wire handlers.
  Future<void> initAndRegister() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM: notification permission denied');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);

      _messaging.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('FCM foreground: ${message.notification?.title}');
        _handleNotificationTap(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
    } catch (e) {
      debugPrint('FCM init error: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final stored = await _storage.getAccessToken();
      if (stored == null) return;
      final deviceId = await _storage.getOrCreateDeviceId();
      await _profile.registerFcmToken(token: token, deviceId: deviceId);
      debugPrint('FCM token registered');
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Route through the root navigator. If the app hasn't booted yet (e.g.
    // terminated-state launch firing before the first frame), defer one
    // microtask — the navigator is built synchronously by then.
    void run() {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      final type = message.data['type'];
      switch (type) {
        case 'new_match':
          GoRouter.of(ctx).go('/matches');
          break;
        case 'new_message':
          final matchId = message.data['matchId'];
          if (matchId is String && matchId.isNotEmpty) {
            GoRouter.of(ctx).push('/chat/$matchId');
          }
          break;
        case 'new_like':
          GoRouter.of(ctx).go('/home');
          break;
      }
    }

    if (rootNavigatorKey.currentContext != null) {
      run();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    }
  }
}
