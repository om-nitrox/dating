import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/interest_chip.dart';
import '../../../profile_setup/data/profile_repository.dart';

final editProfileProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.read(profileRepositoryProvider);
  final result = await repo.getProfile();
  switch (result) {
    case Success(:final data):
      return data;
    case Failure(:final exception):
      throw exception;
  }
});

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final Set<String> _interests = {};
  List<PhotoModel> _photos = [];
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.updateProfile({
      'name': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'interests': _interests.toList(),
    });

    setState(() => _isLoading = false);

    switch (result) {
      case Success():
        if (mounted) {
          context.showSnackBar('Profile updated');
          context.pop();
        }
      case Failure(:final exception):
        if (mounted) {
          context.showSnackBar(exception.message, isError: true);
        }
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= AppConstants.maxPhotos) {
      context.showSnackBar('Maximum ${AppConstants.maxPhotos} photos allowed', isError: true);
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.uploadPhotos([File(picked.path)]);

    setState(() => _isUploadingPhoto = false);

    switch (result) {
      case Success(:final data):
        setState(() => _photos = data);
      case Failure(:final exception):
        if (mounted) {
          context.showSnackBar(exception.message, isError: true);
        }
    }
  }

  Future<void> _deletePhoto(PhotoModel photo) async {
    if (_photos.length <= AppConstants.minPhotos) {
      context.showSnackBar(
        'Minimum ${AppConstants.minPhotos} photos required',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.deletePhoto(photo.publicId);

    switch (result) {
      case Success():
        setState(() => _photos.removeWhere((p) => p.publicId == photo.publicId));
      case Failure(:final exception):
        if (mounted) {
          context.showSnackBar(exception.message, isError: true);
        }
    }
  }

  void _onReorderPhoto(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final photo = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, photo);
    });

    // Save new order to backend
    final repo = ref.read(profileRepositoryProvider);
    repo.reorderPhotos(_photos.map((p) => p.publicId).toList());
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(editProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (!_initialized) {
            _nameController.text = user.name ?? '';
            _bioController.text = user.bio ?? '';
            _interests.addAll(user.interests);
            _photos = List.from(user.photos);
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photos section
                const Text('Photos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'Drag to reorder. First photo is your main photo.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                _PhotoGrid(
                  photos: _photos,
                  isUploading: _isUploadingPhoto,
                  onAdd: _addPhoto,
                  onDelete: _deletePhoto,
                  onReorder: _onReorderPhoto,
                ),
                const SizedBox(height: 24),

                AppTextField(
                  controller: _nameController,
                  labelText: 'Name',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _bioController,
                  labelText: 'Bio',
                  maxLines: 4,
                  maxLength: AppConstants.maxBioLength,
                ),
                const SizedBox(height: 24),
                const Text('Interests',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.availableInterests.map((interest) {
                    return InterestChip(
                      label: interest,
                      isSelected: _interests.contains(interest),
                      onTap: () {
                        setState(() {
                          if (_interests.contains(interest)) {
                            _interests.remove(interest);
                          } else {
                            _interests.add(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<PhotoModel> photos;
  final bool isUploading;
  final VoidCallback onAdd;
  final void Function(PhotoModel) onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _PhotoGrid({
    required this.photos,
    required this.isUploading,
    required this.onAdd,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    for (var i = 0; i < photos.length; i++) {
      items.add(
        ReorderableDragStartListener(
          index: i,
          key: ValueKey(photos[i].publicId),
          child: _PhotoTile(
            photo: photos[i],
            isMain: i == 0,
            onDelete: () => onDelete(photos[i]),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 130,
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            onReorder: onReorder,
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: child,
              );
            },
            footer: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _AddPhotoTile(
                onTap: isUploading ? null : onAdd,
                isUploading: isUploading,
              ),
            ),
            children: [
              for (var i = 0; i < photos.length; i++)
                Padding(
                  key: ValueKey(photos[i].publicId),
                  padding: const EdgeInsets.only(right: 8),
                  child: _PhotoTile(
                    photo: photos[i],
                    isMain: i == 0,
                    onDelete: () => onDelete(photos[i]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final PhotoModel photo;
  final bool isMain;
  final VoidCallback onDelete;

  const _PhotoTile({
    required this.photo,
    required this.isMain,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 130,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AppCachedImage(
              imageUrl: photo.url,
              width: 100,
              height: 130,
            ),
          ),
          if (isMain)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Main',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isUploading;

  const _AddPhotoTile({this.onTap, required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textHint, width: 1.5),
          color: AppColors.surfaceVariant,
        ),
        child: Center(
          child: isUploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
