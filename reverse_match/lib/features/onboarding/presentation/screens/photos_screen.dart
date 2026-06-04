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

  Future<void> _pickFromSource(ImageSource source) async {
    final photos = ref.read(onboardingProvider).photos;
    if (photos.length >= _slots) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (img != null) {
      ref.read(onboardingProvider.notifier).addPhoto(File(img.path));
    }
  }

  Future<void> _showSourceSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                _SourceTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromSource(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                _SourceTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take a photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromSource(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(onboardingProvider).photos;
    final canProceed = photos.length >= _minPhotos;
    final remaining = _minPhotos - photos.length;

    return OnboardingScaffold(
      title: 'Add your best photos',
      subtitle:
          'Pick at least $_minPhotos. Drag to reorder — your first photo is your main one.',
      progress: OnboardingSteps.progress('/onboarding/photos'),
      onNext: canProceed
          ? () => context.push(OnboardingSteps.next('/onboarding/photos')!)
          : null,
      nextLabel: canProceed
          ? 'Continue'
          : (remaining == 1 ? 'Add 1 more photo' : 'Add $remaining more'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CountIndicator(count: photos.length, max: _slots),
          const SizedBox(height: 16),
          _PhotoGrid(
            photos: photos,
            slots: _slots,
            onAdd: _showSourceSheet,
            onRemove: (i) =>
                ref.read(onboardingProvider.notifier).removePhoto(i),
            onReorder: (oldI, newI) => ref
                .read(onboardingProvider.notifier)
                .reorderPhotos(oldI, newI),
          ),
          const SizedBox(height: 18),
          const _Hint(
            icon: Icons.tips_and_updates_outlined,
            text:
                'Tip: A clear, smiling solo shot makes the best first photo. Avoid sunglasses or group photos for #1.',
          ),
        ],
      ),
    );
  }
}

class _CountIndicator extends StatelessWidget {
  final int count;
  final int max;

  const _CountIndicator({required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_outlined,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '$count of $max',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<File> photos;
  final int slots;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int oldI, int newI) onReorder;

  const _PhotoGrid({
    required this.photos,
    required this.slots,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        const cols = 3;
        final tileSize =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;
        final tileHeight = tileSize / 0.75;

        final items = <Widget>[];
        for (var i = 0; i < photos.length; i++) {
          items.add(_PhotoSlot(
            key: ValueKey('photo-${photos[i].path}'),
            file: photos[i],
            isPrimary: i == 0,
            index: i,
            onRemove: () => onRemove(i),
            size: Size(tileSize, tileHeight),
          ));
        }
        for (var i = photos.length; i < slots; i++) {
          items.add(_EmptySlot(
            key: ValueKey('empty-$i'),
            onTap: onAdd,
            isNextToFill: i == photos.length,
            size: Size(tileSize, tileHeight),
          ));
        }

        return ReorderableWrap(
          spacing: spacing,
          runSpacing: spacing,
          onReorder: (oldIndex, newIndex) {
            if (oldIndex >= photos.length) return;
            if (newIndex > photos.length) newIndex = photos.length;
            onReorder(oldIndex, newIndex);
          },
          children: items,
        );
      },
    );
  }
}

/// Lightweight reorderable wrap — wraps children in a Wrap and supports drag
/// via LongPressDraggable + DragTarget. We roll our own instead of pulling
/// the reorderables package since we only need basic reorder-on-drop here.
class ReorderableWrap extends StatefulWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ReorderableWrap({
    super.key,
    required this.children,
    required this.spacing,
    required this.runSpacing,
    required this.onReorder,
  });

  @override
  State<ReorderableWrap> createState() => _ReorderableWrapState();
}

class _ReorderableWrapState extends State<ReorderableWrap> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: List.generate(widget.children.length, (i) {
        final child = widget.children[i];
        return DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            setState(() => _hoverIndex = i);
            return details.data != i;
          },
          onLeave: (_) {
            if (_hoverIndex == i) setState(() => _hoverIndex = null);
          },
          onAcceptWithDetails: (details) {
            setState(() => _hoverIndex = null);
            widget.onReorder(details.data, i);
          },
          builder: (_, candidate, __) {
            final highlighted = candidate.isNotEmpty;
            return AnimatedScale(
              scale: highlighted ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: LongPressDraggable<int>(
                data: i,
                delay: const Duration(milliseconds: 220),
                feedback: Material(
                  color: Colors.transparent,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: Opacity(opacity: 0.9, child: child),
                ),
                childWhenDragging: Opacity(opacity: 0.3, child: child),
                child: child,
              ),
            );
          },
        );
      }),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final File file;
  final bool isPrimary;
  final int index;
  final VoidCallback onRemove;
  final Size size;

  const _PhotoSlot({
    super.key,
    required this.file,
    required this.isPrimary,
    required this.index,
    required this.onRemove,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(file, fit: BoxFit.cover),
          ),
          // Gradient overlay at top to make X button readable
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (isPrimary)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded,
                        color: Colors.white, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Main',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child:
                    const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final VoidCallback onTap;
  final bool isNextToFill;
  final Size size;

  const _EmptySlot({
    super.key,
    required this.onTap,
    required this.isNextToFill,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isNextToFill ? AppColors.primary : AppColors.divider;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: isNextToFill
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: isNextToFill ? 0.5 : 0.6),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    accent.withValues(alpha: isNextToFill ? 0.15 : 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: isNextToFill ? AppColors.primary : AppColors.textHint,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
