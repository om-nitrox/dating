import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(
    ref.read(dioProvider),
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
  final Dio _dio;
  final SecureStorageService _storage;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  FcmService(this._dio, this._storage);

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
      await _dio.put(ApiEndpoints.profile, data: {'fcmToken': token});
      debugPrint('FCM token registered');
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    switch (type) {
      case 'new_match':
        debugPrint('FCM: new match → navigate to /matches');
        break;
      case 'new_message':
        final matchId = message.data['matchId'];
        debugPrint('FCM: new message in match $matchId → navigate to /chat/$matchId');
        break;
      case 'new_like':
        debugPrint('FCM: new like → navigate to /home');
        break;
    }
  }
}
