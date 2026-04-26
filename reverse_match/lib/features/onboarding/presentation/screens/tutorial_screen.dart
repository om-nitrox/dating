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

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  bool _submitting = false;

  Future<void> _finish() async {
    setState(() => _submitting = true);

    // Defensive auth check — the router should prevent unauth'd users from ever
    // reaching this screen, but if secure storage was cleared mid-flow (e.g. a
    // backend session revoke), we surface a clear message instead of an opaque
    // "No token provided" error.
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

    // 1. Upload photos (backend)
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

    // 2. Upload selfie (non-blocking — failure here shouldn't abort onboarding;
    //    user can verify later from settings).
    if (data.selfieFile != null) {
      await repo.uploadSelfie(data.selfieFile!);
    }

    // 3. Submit full profile payload (all Hinge-style fields)
    final payload = controller.backendPayload();
    final result = payload.isEmpty
        ? const Success(null)
        : await repo.updateProfile(payload);

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Success():
        await ref.read(localStorageProvider).setProfileComplete(true);
        if (data.gender != null) {
          await ref
              .read(secureStorageProvider)
              .saveUserGender(data.gender!);
        }
        if (mounted) context.go('/home');
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

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'How liking works',
      subtitle:
          "Tap a photo or prompt to like it. Add a comment to stand out. If it's mutual, you'll match.",
      nextLabel: _submitting ? 'Setting up…' : 'Start exploring',
      onNext: _submitting ? null : _finish,
      showBack: false,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 220,
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.person,
                            size: 120, color: AppColors.textHint),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '← Tap the heart to like a specific photo or prompt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _tip(Icons.favorite_outline,
              'Like a photo or prompt to show interest'),
          _tip(Icons.chat_bubble_outline,
              'Add a comment to make your like stand out'),
          _tip(Icons.star_outline,
              'Send a Rose to show extra interest'),
        ],
      ),
    );
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
