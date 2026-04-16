import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/interest_chip.dart';
import '../../data/profile_repository.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Form data
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  String? _gender;
  final List<File> _photos = [];
  final Set<String> _interests = {};
  double _ageMin = 18;
  double _ageMax = 50;
  double _maxDistance = 50;
  double? _latitude;
  double? _longitude;

  final _totalSteps = 6;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= AppConstants.maxPhotos) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 1000,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _photos.add(File(image.path)));
    }
  }

  Future<void> _detectLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) context.showSnackBar('Location permission denied', isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _cityController.text = 'Location detected';
      });
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to get location', isError: true);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final repo = ref.read(profileRepositoryProvider);

    // Upload photos first
    if (_photos.isNotEmpty) {
      final photoResult = await repo.uploadPhotos(_photos);
      if (photoResult is Failure) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          context.showSnackBar(
            (photoResult as Failure).exception.message,
            isError: true,
          );
        }
        return;
      }
    }

    // Update profile
    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'age': int.parse(_ageController.text.trim()),
      'gender': _gender,
      'bio': _bioController.text.trim(),
      'interests': _interests.toList(),
      'preferences': {
        'ageMin': _ageMin.round(),
        'ageMax': _ageMax.round(),
        'maxDistance': _maxDistance.round(),
      },
    };

    if (_latitude != null && _longitude != null) {
      data['location'] = {
        'coordinates': [_longitude, _latitude],
        'city': _cityController.text.trim(),
      };
    }

    final result = await repo.updateProfile(data);

    setState(() => _isSubmitting = false);

    switch (result) {
      case Success():
        await ref.read(localStorageProvider).setProfileComplete(true);
        if (_gender != null) {
          await ref.read(secureStorageProvider).saveUserGender(_gender!);
        }
        if (mounted) context.go('/home');
      case Failure(:final exception):
        if (mounted) context.showSnackBar(exception.message, isError: true);
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            _ageController.text.isNotEmpty &&
            _gender != null;
      case 1:
        return _photos.length >= AppConstants.minPhotos;
      case 2:
        return true; // Bio is optional
      case 3:
        return _interests.length >= AppConstants.minInterests;
      case 4:
        return true; // Location optional
      case 5:
        return true; // Preferences have defaults
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of $_totalSteps'),
        leading: _currentStep > 0
            ? BackButton(onPressed: _prevStep)
            : null,
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
          // Steps
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfo(),
                _buildPhotos(),
                _buildBio(),
                _buildInterests(),
                _buildLocation(),
                _buildPreferences(),
              ],
            ),
          ),
          // Next button
          Padding(
            padding: const EdgeInsets.all(24),
            child: AppButton(
              label: _currentStep == _totalSteps - 1 ? 'Complete' : 'Next',
              isLoading: _isSubmitting,
              onPressed: _canProceed ? _nextStep : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Basic Info',
              style: context.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          AppTextField(
            controller: _nameController,
            labelText: 'Name',
            hintText: 'Your name',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _ageController,
            labelText: 'Age',
            hintText: 'Your age',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Gender', style: context.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GenderButton(
                  label: 'Male',
                  icon: Icons.male,
                  isSelected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderButton(
                  label: 'Female',
                  icon: Icons.female,
                  isSelected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotos() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Photos',
              style: context.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Add at least ${AppConstants.minPhotos} photos',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: _photos.length + 1,
              itemBuilder: (context, index) {
                if (index == _photos.length) {
                  if (_photos.length >= AppConstants.maxPhotos) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Icon(Icons.add_a_photo,
                          color: AppColors.textSecondary, size: 32),
                    ),
                  );
                }
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_photos[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(index)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBio() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About You',
              style: context.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          AppTextField(
            controller: _bioController,
            hintText: 'Tell people about yourself...',
            maxLines: 5,
            maxLength: AppConstants.maxBioLength,
          ),
        ],
      ),
    );
  }

  Widget _buildInterests() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Interests',
              style: context.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Select at least ${AppConstants.minInterests}',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location',
              style: context.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          AppButton(
            label: 'Detect My Location',
            icon: Icons.my_location,
            isOutlined: true,
            onPressed: _detectLocation,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _cityController,
            labelText: 'City',
            hintText: 'Or enter your city manually',
          ),
        ],
      ),
    );
  }

  Widget _buildPreferences() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preferences',
              style: context.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Text('Age Range: ${_ageMin.round()} - ${_ageMax.round()}'),
          RangeSlider(
            values: RangeValues(_ageMin, _ageMax),
            min: 18,
            max: 60,
            divisions: 42,
            labels: RangeLabels(
                _ageMin.round().toString(), _ageMax.round().toString()),
            onChanged: (values) {
              setState(() {
                _ageMin = values.start;
                _ageMax = values.end;
              });
            },
          ),
          const SizedBox(height: 24),
          Text('Max Distance: ${_maxDistance.round()} km'),
          Slider(
            value: _maxDistance,
            min: 1,
            max: 200,
            divisions: 199,
            label: '${_maxDistance.round()} km',
            onChanged: (value) => setState(() => _maxDistance = value),
          ),
        ],
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(25) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 32,
                color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                )),
          ],
        ),
      ),
    );
  }
}
