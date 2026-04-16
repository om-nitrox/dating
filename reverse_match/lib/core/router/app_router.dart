import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/boost/presentation/screens/boost_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/home/presentation/screens/boy_home_screen.dart';
import '../../features/home/presentation/screens/girl_home_screen.dart';
import '../../features/match/presentation/screens/matches_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile_setup/presentation/screens/profile_setup_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../network/connectivity_service.dart';
import '../theme/app_colors.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final path = state.matchedLocation;
      final isSplash = path == '/';
      final isPublicRoute = isSplash ||
          path == '/welcome' ||
          path == '/login' ||
          path.startsWith('/otp');

      // Stay on splash while auth is loading
      if (authState is AuthInitial || authState is AuthLoading) {
        return isSplash ? null : '/';
      }

      if (authState is AuthUnauthenticated || authState is AuthError) {
        // Redirect splash and non-public routes to welcome
        if (isSplash || !isPublicRoute) {
          return '/welcome';
        }
        return null;
      }

      if (authState is AuthOtpSent && path != '/otp') {
        return '/otp';
      }

      if (authState is AuthAuthenticated) {
        final user = authState.user;

        // Redirect to profile setup if incomplete
        if (!user.isProfileComplete &&
            user.gender == null &&
            path != '/profile-setup') {
          return '/profile-setup';
        }

        // Redirect away from auth pages
        if (isPublicRoute) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final email = authState is AuthOtpSent
              ? authState.email
              : '';
          return OtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      // Main app shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) {
          return _MainShell(child: child);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) {
                  if (authState is AuthAuthenticated) {
                    final gender = authState.user.gender;
                    if (gender == 'female') return const GirlHomeScreen();
                    return const BoyHomeScreen();
                  }
                  return const BoyHomeScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/matches',
                builder: (_, __) => const MatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (_, state) =>
            ChatScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/boost',
        builder: (_, __) => const BoostScreen(),
      ),
    ],
  );
});

class _MainShell extends ConsumerWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return Scaffold(
      body: Column(
        children: [
          // Offline banner
          if (connectivity == ConnectivityState.disconnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.error,
              child: const Text(
                'No internet connection',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/matches');
            case 2:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _calculateIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/matches')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }
}
