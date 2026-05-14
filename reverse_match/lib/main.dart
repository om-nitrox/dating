import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/router/app_router.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment config. Use --dart-define=ENV=production to switch envs
  // at build time.
  const env = String.fromEnvironment('ENV', defaultValue: 'development');
  final envFile = env == 'production'
      ? '.env.production'
      : env == 'staging'
          ? '.env.staging'
          : '.env';
  await dotenv.load(fileName: envFile);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background FCM handler must be registered before any other FCM setup.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // One ProviderContainer for the whole app. We initialize FCM through it
  // before runApp so the same Dio/SecureStorage instances are reused later.
  final container = ProviderContainer();
  await container.read(fcmServiceProvider).initAndRegister();

  // Start the deep-link listener. The service swallows its own errors so
  // failure here can't block app startup.
  unawaited(container.read(deepLinkServiceProvider).start());

  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';

  if (sentryDsn.isEmpty) {
    // No DSN provided — skip Sentry entirely. Useful in local dev so we
    // don't pay the init cost on every hot restart.
    _runApp(container);
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 0.1;
      options.environment = env;
    },
    appRunner: () => _runApp(container),
  );
}

void _runApp(ProviderContainer container) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  runZonedGuarded(
    () {
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const ReverseMatchApp(),
        ),
      );
    },
    (error, stackTrace) {
      debugPrint('Uncaught error: $error');
      Sentry.captureException(error, stackTrace: stackTrace);
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
