import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

// To enable Sentry, add sentry_flutter to pubspec.yaml and uncomment:
// import 'package:sentry_flutter/sentry_flutter.dart';

// To enable Firebase, add firebase_core + firebase_messaging and uncomment:
// import 'package:firebase_core/firebase_core.dart';

/// Sentry DSN — set your DSN here or via environment config.
const String _sentryDsn = '';

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

  // Initialize Firebase (uncomment when firebase_core is added)
  // await Firebase.initializeApp();

  if (_sentryDsn.isNotEmpty) {
    // Sentry wraps the app to capture errors (uncomment when sentry_flutter is added)
    // await SentryFlutter.init(
    //   (options) {
    //     options.dsn = _sentryDsn;
    //     options.tracesSampleRate = 0.1;
    //     options.environment = 'production';
    //   },
    //   appRunner: () => _runApp(),
    // );
    _runApp();
  } else {
    _runApp();
  }
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
