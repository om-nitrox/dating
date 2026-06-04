import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class SelfieScreen extends ConsumerStatefulWidget {
  const SelfieScreen({super.key});

  @override
  ConsumerState<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends ConsumerState<SelfieScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (img != null) {
      ref.read(onboardingProvider.notifier).setSelfie(File(img.path));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final selfie = ref.watch(onboardingProvider).selfieFile;
    final verified = selfie != null;

    return OnboardingScaffold(
      title: 'Verify yourself',
      subtitle:
          'Quick selfie so we know it\'s you. Your selfie stays private — it\'s never shown on your profile.',
      whyText:
          'Verification keeps Reverse Match real. We compare your selfie to your photos and remove fake accounts that don\'t match.',
      progress: OnboardingSteps.progress('/onboarding/selfie'),
      nextLabel: verified ? 'Looks good — continue' : 'Take selfie first',
      onNext: verified
          ? () => context.push(OnboardingSteps.next('/onboarding/selfie')!)
          : null,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _SelfieFrame(
            selfie: selfie,
            pulse: _pulse,
            verified: verified,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _capture,
              icon: Icon(verified
                  ? Icons.refresh_rounded
                  : Icons.camera_alt_rounded),
              label: Text(
                verified ? 'Retake selfie' : 'Open camera',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: verified
                    ? AppColors.surface
                    : AppColors.primary,
                foregroundColor:
                    verified ? AppColors.primary : Colors.white,
                elevation: verified ? 0 : 1,
                shadowColor: AppColors.primary.withValues(alpha: 0.25),
                side: verified
                    ? const BorderSide(
                        color: AppColors.primary, width: 1.5)
                    : BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (verified) ...[
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Selfie captured — review on the next step',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelfieFrame extends StatelessWidget {
  final File? selfie;
  final AnimationController pulse;
  final bool verified;

  const _SelfieFrame({
    required this.selfie,
    required this.pulse,
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    const size = 240.0;
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final glow = 0.15 + (pulse.value * 0.2);
        return SizedBox(
          width: size + 40,
          height: size + 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing glow ring (only while not verified)
              if (!verified)
                Container(
                  width: size + 30,
                  height: size + 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary
                        .withValues(alpha: glow * 0.5),
                  ),
                ),
              // Main circle
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant,
                  border: Border.all(
                    color: verified
                        ? AppColors.success
                        : AppColors.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (verified
                              ? AppColors.success
                              : AppColors.primary)
                          .withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: selfie != null
                    ? Image.file(selfie!, fit: BoxFit.cover)
                    : const _FaceGuide(),
              ),
              // Verified badge
              if (verified)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FaceGuide extends StatelessWidget {
  const _FaceGuide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.face_outlined,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Center your face',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
