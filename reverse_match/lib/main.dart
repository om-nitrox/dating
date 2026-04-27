import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

// To enable Sentry, add sentry_flutter to pubspec.yaml and uncomment:
// import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment config
  // Use --dart-define=ENV=production to switch envs at build time
  const env = String.fromEnvironment('ENV', defaultValue: 'development');
  final envFile = env == 'production'
      ? '.env.production'
      : env == 'staging'
          ? '.env.staging'
          : '.env';
  await dotenv.load(fileName: envFile);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background handler must be registered before any other FCM setup
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize FCM: permissions, token registration, notification handlers
  final container = ProviderContainer();
  await container.read(fcmServiceProvider).initAndRegister();

  _runApp();
}

void _runApp() {
  // Catch uncaught Flutter errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // If Sentry is enabled: Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  runZonedGuarded(
    () {
      runApp(
        const ProviderScope(
          child: ReverseMatchApp(),
        ),
      );
    },
    (error, stackTrace) {
      debugPrint('Uncaught error: $error');
      // If Sentry is enabled: Sentry.captureException(error, stackTrace: stackTrace);
    },
  );
}

class ReverseMatchApp extends ConsumerWidget {
  const ReverseMatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Reverse Match',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
