import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/boost/presentation/screens/boost_cancel_screen.dart';
import '../../features/boost/presentation/screens/boost_screen.dart';
import '../../features/boost/presentation/screens/boost_success_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/home/presentation/screens/boy_home_screen.dart';
import '../../features/home/presentation/screens/girl_home_screen.dart';
import '../../features/ideal_match/presentation/screens/ideal_match_screen.dart';
import '../../features/match/presentation/screens/matches_screen.dart';
import '../../features/onboarding/presentation/screens/children_screen.dart';
import '../../features/onboarding/presentation/screens/dating_preference_screen.dart';
import '../../features/onboarding/presentation/screens/bio_screen.dart';
import '../../features/onboarding/presentation/screens/dob_screen.dart';
import '../../features/onboarding/presentation/screens/drinking_screen.dart';
import '../../features/onboarding/presentation/screens/drugs_screen.dart';
import '../../features/onboarding/presentation/screens/education_screen.dart';
import '../../features/onboarding/presentation/screens/ethnicity_screen.dart';
import '../../features/onboarding/presentation/screens/exercise_screen.dart';
import '../../features/onboarding/presentation/screens/family_plans_screen.dart';
import '../../features/onboarding/presentation/screens/gender_screen.dart';
import '../../features/onboarding/presentation/screens/height_screen.dart';
import '../../features/onboarding/presentation/screens/hometown_screen.dart';
import '../../features/onboarding/presentation/screens/intentions_screen.dart';
import '../../features/onboarding/presentation/screens/interests_screen.dart';
import '../../features/onboarding/presentation/screens/job_screen.dart';
import '../../features/onboarding/presentation/screens/languages_screen.dart';
import '../../features/onboarding/presentation/screens/location_screen.dart';
import '../../features/onboarding/presentation/screens/marijuana_screen.dart';
import '../../features/onboarding/presentation/screens/name_screen.dart';
import '../../features/onboarding/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/orientation_screen.dart';
import '../../features/onboarding/presentation/screens/photos_screen.dart';
import '../../features/onboarding/presentation/screens/profile_preview_screen.dart';
import '../../features/onboarding/presentation/screens/politics_screen.dart';
import '../../features/onboarding/presentation/screens/preview_screen.dart';
import '../../features/onboarding/presentation/screens/prompts_screen.dart';
import '../../features/onboarding/presentation/screens/pronouns_screen.dart';
import '../../features/onboarding/presentation/screens/relationship_type_screen.dart';
import '../../features/onboarding/presentation/screens/religion_screen.dart';
import '../../features/onboarding/presentation/screens/selfie_screen.dart';
import '../../features/onboarding/presentation/screens/smoking_screen.dart';
import '../../features/onboarding/presentation/screens/tutorial_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/workplace_screen.dart';
import '../../features/onboarding/presentation/screens/zodiac_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile_setup/presentation/screens/profile_setup_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/verification/presentation/screens/admin_verification_queue_screen.dart';
import '../../features/verification/presentation/screens/pending_verification_screen.dart';
import '../../shared/models/user_model.dart';
import '../network/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../theme/clay.dart';

/// Root navigator key — exposed so non-widget code (FCM tap handlers, deep
/// link service) can drive navigation without holding a BuildContext from a
/// widget tree.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects on auth changes via a refreshListenable instead of
  // rebuilding the whole GoRouter. The old `ref.watch(authProvider)` here
  // recreated the entire GoRouter on every auth change, which churned the
  // navigator / StatefulShell and left a black screen after logout or
  // account deletion.
  final authListenable = ValueNotifier<AuthState>(ref.read(authProvider));
  ref.onDispose(authListenable.dispose);
  ref.listen<AuthState>(authProvider, (_, next) => authListenable.value = next);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final path = state.matchedLocation;
      final isSplash = path == '/';
      final isPublicRoute = isSplash ||
          path == '/welcome' ||
          path == '/login' ||
          path.startsWith('/otp');
      final isOnboarding = path.startsWith('/onboarding');

      // Stay on splash only during the genuine cold-start gate (AuthInitial).
      // AuthLoading is set by sendOtp/verifyOtp/google while the user is
      // ALREADY on /login or /otp — bouncing those to splash made the splash
      // re-run checkAuthStatus(), which overwrote AuthOtpSent with
      // AuthUnauthenticated and kicked the user back to /welcome. Let the
      // login/otp screens show their own inline spinners instead.
      if (authState is AuthInitial) {
        return isSplash ? null : '/';
      }
      if (authState is AuthLoading) {
        return null;
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

        // 1. Admins live entirely inside the verification queue — no feed,
        //    matches, settings or onboarding. Pin every route there.
        if (user.isAdmin) {
          return path == '/admin/verification-queue'
              ? null
              : '/admin/verification-queue';
        }

        // Redirect to onboarding if incomplete; allow any /onboarding/* route
        if (!user.isProfileComplete &&
            user.gender == null &&
            path != '/profile-setup' &&
            !isOnboarding) {
          return '/onboarding/name';
        }

        // 2. Girls must be admin-approved before entering the app. While
        //    pending/rejected, keep them on the verification screen. Boys are
        //    never gated. Allow /onboarding/* so a rejected girl can re-shoot
        //    her selfie, and don't fire until onboarding produced a profile.
        if (user.needsVerification &&
            user.isProfileComplete &&
            !isOnboarding &&
            path != '/pending-verification') {
          return '/pending-verification';
        }

        // An approved (or boy) user should never sit on the pending screen.
        if (!user.needsVerification && path == '/pending-verification') {
          return '/home';
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
          final authState = ref.read(authProvider);
          final email = authState is AuthOtpSent ? authState.email : '';
          return OtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      // Girl account-approval waiting screen
      GoRoute(
        path: '/pending-verification',
        builder: (_, __) => const PendingVerificationScreen(),
      ),
      // Admin-only profile verification queue
      GoRoute(
        path: '/admin/verification-queue',
        builder: (_, __) => const AdminVerificationQueueScreen(),
      ),
      // Hinge-style onboarding flow
      GoRoute(
        path: '/onboarding/name',
        builder: (_, __) => const NameScreen(),
      ),
      GoRoute(
        path: '/onboarding/dob',
        builder: (_, __) => const DobScreen(),
      ),
      GoRoute(
        path: '/onboarding/gender',
        builder: (_, __) => const GenderScreen(),
      ),
      GoRoute(
        path: '/onboarding/pronouns',
        builder: (_, __) => const PronounsScreen(),
      ),
      GoRoute(
        path: '/onboarding/orientation',
        builder: (_, __) => const OrientationScreen(),
      ),
      GoRoute(
        path: '/onboarding/dating-pref',
        builder: (_, __) => const DatingPreferenceScreen(),
      ),
      GoRoute(
        path: '/onboarding/location',
        builder: (_, __) => const LocationScreen(),
      ),
      GoRoute(
        path: '/onboarding/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/onboarding/preview-card',
        builder: (_, __) => const ProfilePreviewScreen(),
      ),
      GoRoute(
        path: '/onboarding/height',
        builder: (_, __) => const HeightScreen(),
      ),
      GoRoute(
        path: '/onboarding/ethnicity',
        builder: (_, __) => const EthnicityScreen(),
      ),
      GoRoute(
        path: '/onboarding/children',
        builder: (_, __) => const ChildrenScreen(),
      ),
      GoRoute(
        path: '/onboarding/family-plans',
        builder: (_, __) => const FamilyPlansScreen(),
      ),
      GoRoute(
        path: '/onboarding/hometown',
        builder: (_, __) => const HometownScreen(),
      ),
      GoRoute(
        path: '/onboarding/job',
        builder: (_, __) => const JobScreen(),
      ),
      GoRoute(
        path: '/onboarding/workplace',
        builder: (_, __) => const WorkplaceScreen(),
      ),
      GoRoute(
        path: '/onboarding/education',
        builder: (_, __) => const EducationScreen(),
      ),
      GoRoute(
        path: '/onboarding/religion',
        builder: (_, __) => const ReligionScreen(),
      ),
      GoRoute(
        path: '/onboarding/politics',
        builder: (_, __) => const PoliticsScreen(),
      ),
      GoRoute(
        path: '/onboarding/languages',
        builder: (_, __) => const LanguagesScreen(),
      ),
      GoRoute(
        path: '/onboarding/interests',
        builder: (_, __) => const InterestsScreen(),
      ),
      GoRoute(
        path: '/onboarding/intentions',
        builder: (_, __) => const IntentionsScreen(),
      ),
      GoRoute(
        path: '/onboarding/relationship',
        builder: (_, __) => const RelationshipTypeScreen(),
      ),
      GoRoute(
        path: '/onboarding/drinking',
        builder: (_, __) => const DrinkingScreen(),
      ),
      GoRoute(
        path: '/onboarding/smoking',
        builder: (_, __) => const SmokingScreen(),
      ),
      GoRoute(
        path: '/onboarding/marijuana',
        builder: (_, __) => const MarijuanaScreen(),
      ),
      GoRoute(
        path: '/onboarding/drugs',
        builder: (_, __) => const DrugsScreen(),
      ),
      GoRoute(
        path: '/onboarding/exercise',
        builder: (_, __) => const ExerciseScreen(),
      ),
      GoRoute(
        path: '/onboarding/zodiac',
        builder: (_, __) => const ZodiacScreen(),
      ),
      GoRoute(
        path: '/onboarding/photos',
        builder: (_, __) => const PhotosScreen(),
      ),
      GoRoute(
        path: '/onboarding/prompts',
        builder: (_, __) => const PromptsScreen(),
      ),
      GoRoute(
        path: '/onboarding/bio',
        builder: (_, __) => const BioScreen(),
      ),
      GoRoute(
        path: '/onboarding/selfie',
        builder: (_, __) => const SelfieScreen(),
      ),
      GoRoute(
        path: '/onboarding/preview',
        builder: (_, __) => const PreviewScreen(),
      ),
      GoRoute(
        path: '/onboarding/tutorial',
        builder: (_, __) => const TutorialScreen(),
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
                  final authState = ref.read(authProvider);
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
        builder: (_, state) {
          final extra = state.extra;
          return ChatScreen(
            matchId: state.pathParameters['matchId']!,
            other: extra is UserModel ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/ideal-match',
        builder: (_, __) => const IdealMatchScreen(),
      ),
      GoRoute(
        path: '/boost',
        builder: (_, __) => const BoostScreen(),
      ),
      GoRoute(
        path: '/boost/success',
        builder: (_, __) => const BoostSuccessScreen(),
      ),
      GoRoute(
        path: '/boost/cancel',
        builder: (_, __) => const BoostCancelScreen(),
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

    final index = _calculateIndex(context);
    return Scaffold(
      extendBody: true,
      backgroundColor: Clay.base(context),
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
      bottomNavigationBar: _ClayNavBar(
        index: index,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/matches');
            case 2:
              context.go('/settings');
          }
        },
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

/// Floating claymorphic bottom navigation bar.
class _ClayNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _ClayNavBar({required this.index, required this.onTap});

  static const _items = [
    (Icons.local_fire_department_rounded, 'Home'),
    (Icons.chat_bubble_rounded, 'Matches'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ClayContainer(
        borderRadius: 28,
        depth: 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_items.length, (i) {
            final selected = i == index;
            final (icon, label) = _items[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [AppColors.grape, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
