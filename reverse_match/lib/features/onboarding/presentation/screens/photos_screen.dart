import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  static const int _slots = 6;
  static const int _minPhotos = 3;

  Future<void> _pick() async {
    final photos = ref.read(onboardingProvider).photos;
    if (photos.length >= _slots) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (img != null) {
      ref.read(onboardingProvider.notifier).addPhoto(File(img.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(onboardingProvider).photos;
    final canProceed = photos.length >= _minPhotos;

    return OnboardingScaffold(
      title: 'Add your best photos',
      subtitle:
          'Pick at least $_minPhotos. Tip: a smiling solo shot is the best first photo.',
      progress: OnboardingSteps.progress('/onboarding/photos'),
      onNext: canProceed
          ? () => context.push(OnboardingSteps.next('/onboarding/photos')!)
          : null,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        itemCount: _slots,
        itemBuilder: (context, index) {
          if (index < photos.length) {
            return _PhotoSlot(
              file: photos[index],
              isPrimary: index == 0,
              onRemove: () => ref
                  .read(onboardingProvider.notifier)
                  .removePhoto(index),
            );
          }
          return _EmptySlot(onTap: _pick);
        },
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final File file;
  final bool isPrimary;
  final VoidCallback onRemove;

  const _PhotoSlot({
    required this.file,
    required this.isPrimary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        if (isPrimary)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Main',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptySlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DottedBorder(
        child: const Center(
          child: Icon(Icons.add,
              color: AppColors.primary, size: 32),
        ),
      ),
    );
  }
}

class DottedBorder extends StatelessWidget {
  final Widget child;
  const DottedBorder({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}
