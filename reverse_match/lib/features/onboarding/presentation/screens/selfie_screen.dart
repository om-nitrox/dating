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

class _SelfieScreenState extends ConsumerState<SelfieScreen> {
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
          'Take a quick selfie. We compare it to your photos to confirm you are you. Your selfie is never shown on your profile.',
      whyText:
          'Verification reduces fake profiles and makes Reverse Match a safer place for everyone.',
      progress: OnboardingSteps.progress('/onboarding/selfie'),
      onNext: verified
          ? () => context.push(OnboardingSteps.next('/onboarding/selfie')!)
          : null,
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceVariant,
              border: Border.all(
                color: verified ? AppColors.success : AppColors.primary,
                width: 3,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: selfie != null
                ? Image.file(selfie, fit: BoxFit.cover)
                : const Icon(
                    Icons.face_outlined,
                    size: 80,
                    color: AppColors.textHint,
                  ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              icon: Icon(
                verified ? Icons.refresh : Icons.camera_alt,
                color: AppColors.primary,
              ),
              label: Text(
                verified ? 'Retake selfie' : 'Take selfie',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
              onPressed: _capture,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28),
              ),
            ),
          ),
          if (verified) ...[
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified,
                    color: AppColors.success, size: 18),
                SizedBox(width: 6),
                Text(
                  'Verified ✓',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
