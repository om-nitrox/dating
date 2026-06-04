import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile_setup/data/profile_repository.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

/// Final step — shows liking mechanic, then submits backend-ready fields
/// and drops the user onto /home.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen>
    with TickerProviderStateMixin {
  bool _submitting = false;

  late final AnimationController _tapLoop;

  @override
  void initState() {
    super.initState();
    _tapLoop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _tapLoop.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);

    final token = await ref.read(secureStorageProvider).getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.showSnackBar(
        'Your session has expired. Please sign in again.',
        isError: true,
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) context.go('/welcome');
      });
      return;
    }

    final repo = ref.read(profileRepositoryProvider);
    final data = ref.read(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);

    if (data.photos.isNotEmpty) {
      final res = await repo.uploadPhotos(data.photos);
      if (res is Failure<List<PhotoModel>>) {
        if (mounted) {
          setState(() => _submitting = false);
          context.showSnackBar(res.exception.message, isError: true);
          if (res.exception is UnauthorizedException) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) context.go('/welcome');
            });
          }
        }
        return;
      }
    }

    if (data.selfieFile != null) {
      await repo.uploadSelfie(data.selfieFile!);
    }

    final payload = controller.backendPayload();
    final ApiResult<UserModel?> result = payload.isEmpty
        ? Success(await _fetchFreshProfile(repo))
        : await repo.updateProfile(payload).then<ApiResult<UserModel?>>(
              (r) => switch (r) {
                Success(:final data) => Success<UserModel?>(data),
                Failure(:final exception) => Failure<UserModel?>(exception),
              },
            );

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Success(:final data):
        await ref.read(localStorageProvider).setProfileComplete(true);
        if (data?.gender != null) {
          await ref
              .read(secureStorageProvider)
              .saveUserGender(data!.gender!);
        }
        if (data != null) {
          ref.read(authProvider.notifier).updateUser(data);
        }
        // Girls go to the verification waiting screen (their selfie was just
        // submitted → status 'pending'); everyone else lands on home. The
        // router enforces the same rule, this just avoids a home flash.
        if (mounted) {
          context.go(
            (data?.needsVerification ?? false)
                ? '/pending-verification'
                : '/home',
          );
        }
      case Failure(:final exception):
        if (mounted) {
          context.showSnackBar(exception.message, isError: true);
          if (exception is UnauthorizedException) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) context.go('/welcome');
            });
          }
        }
    }
  }

  Future<UserModel?> _fetchFreshProfile(ProfileRepository repo) async {
    final r = await repo.getProfile();
    return switch (r) {
      Success(:final data) => data,
      Failure() => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'You\'re all set!',
      subtitle:
          'One last thing — here\'s how liking works on Reverse Match.',
      nextLabel: _submitting ? 'Setting up your profile…' : 'Start exploring',
      onNext: _submitting ? null : _finish,
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LikeDemo(loop: _tapLoop),
          const SizedBox(height: 24),
          const _TipCard(
            color: AppColors.primary,
            icon: Icons.favorite_rounded,
            title: 'Tap to like',
            body: 'Like a specific photo or prompt — not just the profile.',
          ),
          const SizedBox(height: 10),
          const _TipCard(
            color: AppColors.secondary,
            icon: Icons.chat_bubble_rounded,
            title: 'Add a comment',
            body: 'Comments stand out 3× more than plain likes.',
          ),
          const SizedBox(height: 10),
          const _TipCard(
            color: AppColors.hot,
            icon: Icons.local_florist_rounded,
            title: 'Send a Rose',
            body: 'Roses signal "I really mean it." Use them wisely.',
          ),
        ],
      ),
    );
  }
}

/// Looping demo: a finger taps a heart, the heart pulses + emits a comment
/// bubble for the rest of the cycle.
class _LikeDemo extends StatelessWidget {
  final AnimationController loop;
  const _LikeDemo({required this.loop});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceVariant,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: AnimatedBuilder(
        animation: loop,
        builder: (_, __) {
          final t = loop.value; // 0 -> 1 over the cycle
          // 0.0 - 0.45  : finger glides toward heart
          // 0.45 - 0.55 : tap (heart pulses big)
          // 0.55 - 1.0  : heart relaxes, comment bubble fades in/out
          final fingerProgress = Curves.easeInOut.transform(
            (t / 0.45).clamp(0.0, 1.0),
          );
          final tap = (t >= 0.43 && t < 0.6) ? 1.0 : 0.0;
          final tapAnim = Curves.elasticOut.transform(
            ((t - 0.43) / 0.17).clamp(0.0, 1.0),
          );
          final heartScale = tap == 0
              ? 1.0
              : 1.0 + 0.35 * tapAnim * (1 - ((t - 0.43) / 0.17).clamp(0.0, 1.0));
          final commentOpacity = (t > 0.55 && t < 0.95)
              ? Curves.easeInOut.transform(((t - 0.55) / 0.4).clamp(0.0, 1.0)) *
                  (t > 0.85 ? (1 - (t - 0.85) / 0.1).clamp(0.0, 1.0) : 1.0)
              : 0.0;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Profile card mock
              Container(
                width: 130,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 70,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 8,
                              width: 60,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(4),
                              )),
                          const SizedBox(height: 4),
                          Container(
                              height: 6,
                              width: 90,
                              decoration: BoxDecoration(
                                color: AppColors.divider
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(3),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Heart button bottom-right of card
              Positioned(
                right: 60,
                bottom: 30,
                child: Transform.scale(
                  scale: heartScale,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: tap == 0 ? 6 : 14,
                          spreadRadius: tap == 0 ? 0 : 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              // Animated finger pointer gliding to heart
              Positioned(
                right: 60 - 80 * (1 - fingerProgress) - 22,
                bottom: 30 - 50 * (1 - fingerProgress) - 22,
                child: Opacity(
                  opacity: (t < 0.55) ? 1.0 : (1.0 - (t - 0.55) / 0.1).clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.touch_app_rounded,
                    size: 38,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Comment bubble that pops up after tap
              Positioned(
                top: 18,
                right: 14,
                child: Opacity(
                  opacity: commentOpacity,
                  child: Transform.translate(
                    offset: Offset(0, (1 - commentOpacity) * 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Loved this!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String body;

  const _TipCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
