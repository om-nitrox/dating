import 'dart:io';

import 'package:dio/dio.dart';
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

/// Handles Firebase Cloud Messaging token registration and notification handling.
///
/// To fully enable FCM:
/// 1. Add firebase_core and firebase_messaging to pubspec.yaml
/// 2. Initialize Firebase in main.dart:
///    await Firebase.initializeApp();
/// 3. Uncomment the Firebase imports and code blocks below
///
/// ```dart
/// // In main.dart after Firebase.initializeApp():
/// final container = ProviderContainer();
/// final fcmService = container.read(fcmServiceProvider);
/// await fcmService.initAndRegister();
/// ```
class FcmService {
  final Dio _dio;
  final SecureStorageService _storage;

  // Uncomment when firebase_messaging is added:
  // import 'package:firebase_messaging/firebase_messaging.dart';
  // static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  FcmService(this._dio, this._storage);

  /// Initialize FCM, request permissions, get token, and send to server.
  /// Also sets up foreground/background notification handlers.
  Future<void> initAndRegister() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;

      // ===== UNCOMMENT BELOW WHEN firebase_messaging IS ADDED =====

      // // Request notification permissions (required on iOS, optional on Android 13+)
      // final settings = await _messaging.requestPermission(
      //   alert: true,
      //   badge: true,
      //   sound: true,
      //   provisional: false,
      // );
      //
      // if (settings.authorizationStatus == AuthorizationStatus.denied) {
      //   debugPrint('FCM: Notification permission denied');
      //   return;
      // }
      //
      // // Get the FCM device token
      // final token = await _messaging.getToken();
      // if (token != null) {
      //   await _registerToken(token);
      // }
      //
      // // Listen for token refreshes (happens periodically)
      // _messaging.onTokenRefresh.listen(_registerToken);
      //
      // // --- FOREGROUND MESSAGES ---
      // // When the app is in the foreground, show an in-app notification
      // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      //   debugPrint('FCM foreground: ${message.notification?.title}');
      //   _handleForegroundMessage(message);
      // });
      //
      // // --- NOTIFICATION TAP (app in background/terminated) ---
      // // User tapped a notification while app was in background
      // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      //   debugPrint('FCM opened: ${message.data}');
      //   _handleNotificationTap(message);
      // });
      //
      // // Check if app was opened from a terminated state via notification
      // final initialMessage = await _messaging.getInitialMessage();
      // if (initialMessage != null) {
      //   _handleNotificationTap(initialMessage);
      // }

      debugPrint('FCM: Service ready (uncomment code when firebase_messaging is added)');
    } catch (e) {
      debugPrint('FCM init error: $e');
    }
  }

  /// Send FCM token to the backend for push notifications.
  Future<void> _registerToken(String token) async {
    try {
      final stored = await _storage.getAccessToken();
      if (stored == null) return;

      await _dio.put(
        ApiEndpoints.profile,
        data: {'fcmToken': token},
      );
      debugPrint('FCM token registered with server');
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  // ===== UNCOMMENT BELOW WHEN firebase_messaging IS ADDED =====

  // /// Handle foreground messages — show in-app overlay or update UI.
  // void _handleForegroundMessage(RemoteMessage message) {
  //   final data = message.data;
  //   final type = data['type'];
  //
  //   switch (type) {
  //     case 'new_like':
  //       // Could show an in-app snackbar or update badge count
  //       debugPrint('New like received');
  //       break;
  //     case 'new_message':
  //       // Could show a toast with message preview
  //       final matchId = data['matchId'];
  //       debugPrint('New message in match: $matchId');
  //       break;
  //     case 'new_match':
  //       debugPrint('New match!');
  //       break;
  //   }
  // }
  //
  // /// Handle notification tap — navigate to the relevant screen.
  // void _handleNotificationTap(RemoteMessage message) {
  //   final data = message.data;
  //   final type = data['type'];
  //
  //   // Navigation should be done via GoRouter from the app's navigator key.
  //   // Store the pending navigation and handle it when the router is ready.
  //   //
  //   // Example with a global navigator key:
  //   // final context = navigatorKey.currentContext;
  //   // if (context == null) return;
  //
  //   switch (type) {
  //     case 'new_like':
  //       // Navigate to home/queue screen
  //       // context.go('/home');
  //       break;
  //     case 'new_message':
  //       final matchId = data['matchId'];
  //       if (matchId != null) {
  //         // context.push('/chat/$matchId');
  //       }
  //       break;
  //     case 'new_match':
  //       // context.go('/matches');
  //       break;
  //   }
  // }
}

// ===== BACKGROUND MESSAGE HANDLER =====
// This must be a top-level function (not a class method).
// Register it in main.dart:
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   // Background messages are handled automatically by the system notification.
//   // This handler is for any custom processing needed (e.g., updating local DB).
//   debugPrint('FCM background: ${message.messageId}');
// }
