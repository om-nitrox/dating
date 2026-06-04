import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/clay.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile_setup/data/profile_repository.dart';
import '../../data/verification_repository.dart';

/// Shown to a girl after she finishes onboarding, while an admin reviews her
/// profile + selfie. A 2-minute countdown is pure UX reassurance — the real
/// gate is the admin. We poll `GET /profile` every 5s and the instant the
/// status flips to `approved` the router drops her into the app. If rejected,
/// she sees the reason and can re-shoot her selfie (→ back to pending).
class PendingVerificationScreen extends ConsumerStatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  ConsumerState<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState
    extends ConsumerState<PendingVerificationScreen> {
  static const _pollInterval = Duration(seconds: 5);
  static const _countdownStart = 120; // seconds (2 min, UX only)

  Timer? _poll;
  Timer? _ticker;
  int _remaining = _countdownStart;
  String? _status; // pending | rejected
  String? _rejectionReason;
  bool _resubmitting = false;

  @override
  void initState() {
    super.initState();
    _status = ref.read(authProvider) is AuthAuthenticated
        ? (ref.read(authProvider) as AuthAuthenticated).user.selfieReviewStatus
        : 'pending';
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining > 0) setState(() => _remaining--);
    });
    _poll = Timer.periodic(_pollInterval, (_) => _checkStatus());
    _checkStatus();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final res = await ref.read(verificationRepositoryProvider).fetchMe();
    if (!mounted) return;
    if (res is Success<UserModel>) {
      final user = res.data;
      // Keep auth state fresh so router redirects stay correct.
      ref.read(authProvider.notifier).updateUser(user);
      if (!user.needsVerification) {
        _poll?.cancel();
        _ticker?.cancel();
        if (mounted) context.go('/home');
        return;
      }
      setState(() {
        _status = user.selfieReviewStatus;
        _rejectionReason = user.selfieRejectionReason;
      });
    }
  }

  Future<void> _retakeSelfie() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (img == null) return;

    setState(() => _resubmitting = true);
    final res =
        await ref.read(profileRepositoryProvider).uploadSelfie(File(img.path));
    if (!mounted) return;
    setState(() => _resubmitting = false);

    if (res case Failure(:final exception)) {
      context.showSnackBar(exception.message, isError: true);
      return;
    }
    setState(() {
      _status = 'pending';
      _rejectionReason = null;
      _remaining = _countdownStart;
    });
    context.showSnackBar('Selfie re-submitted. Back in the review queue.');
    _checkStatus();
  }

  String get _timerLabel {
    final m = (_remaining ~/ 60).toString().padLeft(1, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _status == 'rejected';

    return Scaffold(
      backgroundColor: Clay.base(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _checkStatus,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const SizedBox(height: 24),
              Center(child: _CountdownRing(label: _timerLabel, rejected: rejected)),
              const SizedBox(height: 36),
              Text(
                rejected ? 'Profile needs another look' : 'Profile under verification',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                rejected
                    ? 'Our team couldn\'t verify your profile. Please re-take your selfie to try again.'
                    : 'Our team is reviewing your details and photos. This usually takes only a couple of minutes — the screen will update automatically once you\'re approved.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              if (rejected && _rejectionReason != null) ...[
                const SizedBox(height: 20),
                ClayContainer(
                  borderRadius: 20,
                  depth: 0.7,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _rejectionReason!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (rejected)
                ClayButton(
                  gradient: const LinearGradient(
                    colors: [AppColors.grape, AppColors.primary],
                  ),
                  onTap: _resubmitting ? null : _retakeSelfie,
                  child: Center(
                    child: Text(
                      _resubmitting ? 'Uploading…' : 'Re-take selfie',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                const _WaitingHint(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingHint extends StatelessWidget {
  const _WaitingHint();

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      borderRadius: 20,
      depth: 0.7,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Checking for approval…',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final String label;
  final bool rejected;
  const _CountdownRing({required this.label, required this.rejected});

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      width: 160,
      height: 160,
      borderRadius: 80,
      depth: 1.1,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rejected ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
              size: 40,
              color: rejected ? AppColors.error : AppColors.grape,
            ),
            const SizedBox(height: 8),
            Text(
              rejected ? 'Action needed' : label,
              style: TextStyle(
                fontSize: rejected ? 14 : 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: rejected ? 0 : 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
