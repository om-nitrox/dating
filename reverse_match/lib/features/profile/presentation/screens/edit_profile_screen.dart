import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/taxonomies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/clay.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
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

// ---- option sets that aren't already closed enums in taxonomies.dart ----
const _genderOpts = {'male': 'Man', 'female': 'Woman', 'nonbinary': 'Nonbinary'};
const _pronounOpts = [
  'he/him', 'she/her', 'they/them', 'he/they', 'she/they', 'other'
];
const _orientationOpts = [
  'straight', 'gay', 'lesbian', 'bisexual', 'pansexual', 'asexual', 'queer',
  'questioning', 'other'
];
const _ethnicityOpts = [
  'Asian', 'Black', 'Hispanic/Latino', 'Middle Eastern', 'Native American',
  'Pacific Islander', 'South Asian', 'White', 'Mixed', 'Other'
];
const _languageOpts = [
  'English', 'Hindi', 'Spanish', 'Mandarin', 'French', 'Arabic', 'Portuguese',
  'Bengali', 'Tamil', 'Telugu', 'Russian', 'Japanese', 'Other'
];
const _promptQuestions = [
  'A quick rant about',
  "I'm weirdly attracted to",
  'My simple pleasures',
  'The way to win me over is',
  'I geek out on',
  'My most irrational fear',
  "We'll get along if",
  'Green flags I look for',
  'My ideal first date',
  'Two truths and a lie',
  'The key to my heart is',
  "I'm looking for",
  'Dating me is like',
  'My love language is',
  'Best travel story',
  'A life goal of mine',
];

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // text
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _jobController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _educationController = TextEditingController();
  final _hometownController = TextEditingController();
  final _religionController = TextEditingController();

  // single-select enums
  String? _gender;
  String? _children;
  String? _familyPlans;
  String? _datingIntentions;
  String? _relationshipType;
  String? _politics;
  String? _exercise;
  String? _zodiac;
  String? _drinking;
  String? _smoking;
  String? _marijuana;
  String? _drugs;
  int? _height;

  // multi-select
  final List<String> _ethnicity = [];
  final List<String> _pronouns = [];
  final List<String> _orientation = [];
  final List<String> _languages = [];
  final Set<String> _interests = {};

  List<PromptModel> _prompts = [];
  List<PhotoModel> _photos = [];

  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bioController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _jobController.dispose();
    _workplaceController.dispose();
    _educationController.dispose();
    _hometownController.dispose();
    _religionController.dispose();
    super.dispose();
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _heightLabel(int cm) {
    final totalIn = (cm / 2.54).round();
    final ft = totalIn ~/ 12;
    final inch = totalIn % 12;
    return "$cm cm  ·  $ft' $inch\"";
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'interests': _interests.toList(),
      'jobTitle': _jobController.text.trim(),
      'workplace': _workplaceController.text.trim(),
      'education': _educationController.text.trim(),
      'hometown': _hometownController.text.trim(),
      'religion': _religionController.text.trim(),
      'ethnicity': _ethnicity,
      'pronouns': _pronouns,
      'orientation': _orientation,
      'languages': _languages,
      'prompts': _prompts
          .map((p) => {'question': p.question, 'answer': p.answer})
          .toList(),
    };
    if (_height != null) payload['height'] = _height;
    if (_gender != null) payload['gender'] = _gender;
    if (_children != null) payload['children'] = _children;
    if (_familyPlans != null) payload['familyPlans'] = _familyPlans;
    if (_datingIntentions != null) {
      payload['datingIntentions'] = _datingIntentions;
    }
    if (_relationshipType != null) {
      payload['relationshipType'] = _relationshipType;
    }
    if (_politics != null) payload['politics'] = _politics;
    if (_exercise != null) payload['exercise'] = _exercise;
    if (_zodiac != null) payload['zodiac'] = _zodiac;

    final vices = <String, dynamic>{};
    if (_drinking != null) vices['drinking'] = _drinking;
    if (_smoking != null) vices['smoking'] = _smoking;
    if (_marijuana != null) vices['marijuana'] = _marijuana;
    if (_drugs != null) vices['drugs'] = _drugs;
    if (vices.isNotEmpty) payload['vices'] = vices;

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.updateProfile(payload);

    if (!mounted) return;
    setState(() => _isSaving = false);

    switch (result) {
      case Success():
        context.showSnackBar('Profile updated');
        context.pop();
      case Failure(:final exception):
        context.showSnackBar(exception.message, isError: true);
    }
  }

  // ----------------------- pickers -----------------------

  Future<void> _pickSingle({
    required String title,
    required Map<String, String> labels,
    required String? current,
    required ValueChanged<String?> onPicked,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SheetScaffold(
        title: title,
        onClear: current != null ? () => Navigator.pop(ctx, '__clear__') : null,
        child: Flexible(
          child: ListView(
            shrinkWrap: true,
            children: labels.entries.map((e) {
              final sel = e.key == current;
              return ListTile(
                title: Text(e.value,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textPrimary)),
                trailing: sel
                    ? const Icon(Icons.check_rounded, color: AppColors.grape)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (picked == null) return;
    onPicked(picked == '__clear__' ? null : picked);
  }

  Future<void> _pickMulti({
    required String title,
    required List<String> options,
    required List<String> current,
    required int max,
    String Function(String)? display,
    required ValueChanged<List<String>> onDone,
  }) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MultiSelectSheet(
        title: title,
        options: options,
        current: current,
        max: max,
        display: display,
      ),
    );
    if (result != null) onDone(result);
  }

  Future<void> _pickHeight() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SheetScaffold(
        title: 'Height',
        child: Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var cm = 140; cm <= 210; cm++)
                ListTile(
                  title: Text(_heightLabel(cm),
                      style: const TextStyle(
                          fontSize: 16, color: AppColors.textPrimary)),
                  trailing: cm == _height
                      ? const Icon(Icons.check_rounded, color: AppColors.grape)
                      : null,
                  onTap: () => Navigator.pop(ctx, cm),
                ),
            ],
          ),
        ),
      ),
    );
    if (result != null) setState(() => _height = result);
  }

  Future<void> _editPrompt({PromptModel? existing, int? index}) async {
    final result = await showModalBottomSheet<PromptModel>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PromptEditorSheet(existing: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _prompts[index] = result;
      } else {
        _prompts = [..._prompts, result];
      }
    });
  }

  // ----------------------- photos -----------------------

  Future<void> _addPhoto() async {
    if (_photos.length >= AppConstants.maxPhotos) {
      context.showSnackBar('Maximum ${AppConstants.maxPhotos} photos allowed',
          isError: true);
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.uploadPhotos([File(picked.path)]);
    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);

    switch (result) {
      case Success(:final data):
        setState(() => _photos = data);
      case Failure(:final exception):
        context.showSnackBar(exception.message, isError: true);
    }
  }

  Future<void> _deletePhoto(PhotoModel photo) async {
    if (_photos.length <= AppConstants.minPhotos) {
      context.showSnackBar('Minimum ${AppConstants.minPhotos} photos required',
          isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Photo'),
        content: const Text('Remove this photo from your profile?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.deletePhoto(photo.publicId);
    if (!mounted) return;
    switch (result) {
      case Success():
        setState(
            () => _photos.removeWhere((p) => p.publicId == photo.publicId));
      case Failure(:final exception):
        context.showSnackBar(exception.message, isError: true);
    }
  }

  void _onReorderPhoto(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final photo = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, photo);
    });
    final repo = ref.read(profileRepositoryProvider);
    repo.reorderPhotos(_photos.map((p) => p.publicId).toList());
  }

  // ----------------------- build -----------------------

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(editProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (user) {
          if (!_initialized) {
            _nameController.text = user.name ?? '';
            _bioController.text = user.bio ?? '';
            _jobController.text = user.jobTitle ?? '';
            _workplaceController.text = user.workplace ?? '';
            _educationController.text = user.education ?? '';
            _hometownController.text = user.hometown ?? '';
            _religionController.text = user.religion ?? '';
            _interests.addAll(user.interests);
            _photos = List.from(user.photos);
            _prompts = List.from(user.prompts);
            _height = user.height;
            _gender = user.gender;
            _children = user.children;
            _familyPlans = user.familyPlans;
            _datingIntentions = user.datingIntentions;
            _relationshipType = user.relationshipType;
            _politics = user.politics;
            _exercise = user.exercise;
            _zodiac = user.zodiac;
            _drinking = user.vices?.drinking;
            _smoking = user.vices?.smoking;
            _marijuana = user.vices?.marijuana;
            _drugs = user.vices?.drugs;
            _ethnicity.addAll(user.ethnicity);
            _pronouns.addAll(user.pronouns);
            _orientation.addAll(user.orientation);
            _languages.addAll(user.languages);
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Photos ----
                const _SectionHeader(
                  icon: Icons.photo_library_rounded,
                  title: 'Photos',
                  subtitle:
                      'Drag to reorder. Your first photo is your main one.',
                ),
                const SizedBox(height: 12),
                _PhotoStrip(
                  photos: _photos,
                  isUploading: _isUploadingPhoto,
                  onAdd: _addPhoto,
                  onDelete: _deletePhoto,
                  onReorder: _onReorderPhoto,
                ),

                // ---- Prompts ----
                const SizedBox(height: 28),
                const _SectionHeader(
                  icon: Icons.format_quote_rounded,
                  title: 'Prompts',
                  subtitle: 'Up to 3. These spark conversations.',
                ),
                const SizedBox(height: 12),
                ..._buildPrompts(),

                // ---- About you ----
                const SizedBox(height: 28),
                const _SectionHeader(
                    icon: Icons.person_rounded, title: 'About you'),
                const SizedBox(height: 12),
                _LabelledField(
                  label: 'Name',
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(hintText: 'Your first name'),
                  ),
                ),
                const SizedBox(height: 16),
                _LabelledField(
                  label: 'Bio',
                  trailing: Text(
                    '${_bioController.text.length}/${AppConstants.maxBioLength}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _bioController.text.length >
                              AppConstants.maxBioLength
                          ? AppColors.error
                          : AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: TextField(
                    controller: _bioController,
                    maxLines: 5,
                    minLines: 3,
                    maxLength: AppConstants.maxBioLength,
                    decoration: const InputDecoration(
                      hintText:
                          'Tell people something about you. Hobbies, what you\'re looking for, anything that makes you, you.',
                      counterText: '',
                    ),
                  ),
                ),

                // ---- My Vitals ----
                const SizedBox(height: 28),
                const _SectionHeader(
                    icon: Icons.straighten_rounded, title: 'My Vitals'),
                const SizedBox(height: 12),
                _PickerRow(
                  label: 'Gender',
                  value: _gender == null ? null : _genderOpts[_gender],
                  onTap: () => _pickSingle(
                    title: 'Gender',
                    labels: _genderOpts,
                    current: _gender,
                    onPicked: (v) => setState(() => _gender = v),
                  ),
                ),
                _PickerRow(
                  label: 'Height',
                  value: _height == null ? null : _heightLabel(_height!),
                  onTap: _pickHeight,
                ),
                _PickerRow(
                  label: 'Pronouns',
                  value: _pronouns.isEmpty ? null : _pronouns.join(', '),
                  onTap: () => _pickMulti(
                    title: 'Pronouns',
                    options: _pronounOpts,
                    current: _pronouns,
                    max: 3,
                    onDone: (v) =>
                        setState(() => _pronouns..clear()..addAll(v)),
                  ),
                ),
                _PickerRow(
                  label: 'Orientation',
                  value: _orientation.isEmpty
                      ? null
                      : _orientation.map(_cap).join(', '),
                  onTap: () => _pickMulti(
                    title: 'Sexual orientation',
                    options: _orientationOpts,
                    current: _orientation,
                    max: 3,
                    display: _cap,
                    onDone: (v) =>
                        setState(() => _orientation..clear()..addAll(v)),
                  ),
                ),
                _PickerRow(
                  label: 'Ethnicity',
                  value: _ethnicity.isEmpty ? null : _ethnicity.join(', '),
                  onTap: () => _pickMulti(
                    title: 'Ethnicity',
                    options: _ethnicityOpts,
                    current: _ethnicity,
                    max: 3,
                    onDone: (v) =>
                        setState(() => _ethnicity..clear()..addAll(v)),
                  ),
                ),
                _PickerRow(
                  label: 'Children',
                  value: _children == null ? null : Children.labels[_children],
                  onTap: () => _pickSingle(
                    title: 'Children',
                    labels: Children.labels,
                    current: _children,
                    onPicked: (v) => setState(() => _children = v),
                  ),
                ),
                _PickerRow(
                  label: 'Family plans',
                  value: _familyPlans == null
                      ? null
                      : FamilyPlans.labels[_familyPlans],
                  onTap: () => _pickSingle(
                    title: 'Family plans',
                    labels: FamilyPlans.labels,
                    current: _familyPlans,
                    onPicked: (v) => setState(() => _familyPlans = v),
                  ),
                ),

                // ---- My Virtues ----
                const SizedBox(height: 28),
                const _SectionHeader(
                    icon: Icons.workspace_premium_rounded,
                    title: 'My Virtues'),
                const SizedBox(height: 12),
                _LabelledField(
                  label: 'Job title',
                  child: TextField(
                    controller: _jobController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'e.g. Designer'),
                  ),
                ),
                const SizedBox(height: 16),
                _LabelledField(
                  label: 'Workplace',
                  child: TextField(
                    controller: _workplaceController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Where you work'),
                  ),
                ),
                const SizedBox(height: 16),
                _LabelledField(
                  label: 'Education',
                  child: TextField(
                    controller: _educationController,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(hintText: 'School / college'),
                  ),
                ),
                const SizedBox(height: 16),
                _LabelledField(
                  label: 'Hometown',
                  child: TextField(
                    controller: _hometownController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Where you\'re from'),
                  ),
                ),
                const SizedBox(height: 16),
                _LabelledField(
                  label: 'Religion',
                  child: TextField(
                    controller: _religionController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Your beliefs'),
                  ),
                ),
                const SizedBox(height: 16),
                _PickerRow(
                  label: 'Languages',
                  value: _languages.isEmpty ? null : _languages.join(', '),
                  onTap: () => _pickMulti(
                    title: 'Languages',
                    options: _languageOpts,
                    current: _languages,
                    max: 5,
                    onDone: (v) =>
                        setState(() => _languages..clear()..addAll(v)),
                  ),
                ),
                _PickerRow(
                  label: 'Dating intentions',
                  value: _datingIntentions == null
                      ? null
                      : DatingIntentions.labels[_datingIntentions],
                  onTap: () => _pickSingle(
                    title: 'Dating intentions',
                    labels: DatingIntentions.labels,
                    current: _datingIntentions,
                    onPicked: (v) => setState(() => _datingIntentions = v),
                  ),
                ),
                _PickerRow(
                  label: 'Relationship type',
                  value: _relationshipType == null
                      ? null
                      : RelationshipType.labels[_relationshipType],
                  onTap: () => _pickSingle(
                    title: 'Relationship type',
                    labels: RelationshipType.labels,
                    current: _relationshipType,
                    onPicked: (v) => setState(() => _relationshipType = v),
                  ),
                ),
                _PickerRow(
                  label: 'Politics',
                  value: _politics == null ? null : Politics.labels[_politics],
                  onTap: () => _pickSingle(
                    title: 'Politics',
                    labels: Politics.labels,
                    current: _politics,
                    onPicked: (v) => setState(() => _politics = v),
                  ),
                ),

                // ---- My Vices ----
                const SizedBox(height: 28),
                const _SectionHeader(
                    icon: Icons.local_bar_rounded, title: 'My Vices'),
                const SizedBox(height: 12),
                _PickerRow(
                  label: 'Drinking',
                  value:
                      _drinking == null ? null : ViceLevels.labels[_drinking],
                  onTap: () => _pickSingle(
                    title: 'Drinking',
                    labels: ViceLevels.labels,
                    current: _drinking,
                    onPicked: (v) => setState(() => _drinking = v),
                  ),
                ),
                _PickerRow(
                  label: 'Smoking',
                  value: _smoking == null ? null : ViceLevels.labels[_smoking],
                  onTap: () => _pickSingle(
                    title: 'Smoking',
                    labels: ViceLevels.labels,
                    current: _smoking,
                    onPicked: (v) => setState(() => _smoking = v),
                  ),
                ),
                _PickerRow(
                  label: 'Marijuana',
                  value:
                      _marijuana == null ? null : ViceLevels.labels[_marijuana],
                  onTap: () => _pickSingle(
                    title: 'Marijuana',
                    labels: ViceLevels.labels,
                    current: _marijuana,
                    onPicked: (v) => setState(() => _marijuana = v),
                  ),
                ),
                _PickerRow(
                  label: 'Drugs',
                  value: _drugs == null ? null : ViceLevels.labels[_drugs],
                  onTap: () => _pickSingle(
                    title: 'Drugs',
                    labels: ViceLevels.labels,
                    current: _drugs,
                    onPicked: (v) => setState(() => _drugs = v),
                  ),
                ),

                // ---- Lifestyle ----
                const SizedBox(height: 28),
                const _SectionHeader(
                    icon: Icons.self_improvement_rounded, title: 'Lifestyle'),
                const SizedBox(height: 12),
                _PickerRow(
                  label: 'Exercise',
                  value: _exercise == null ? null : Exercise.labels[_exercise],
                  onTap: () => _pickSingle(
                    title: 'Exercise',
                    labels: Exercise.labels,
                    current: _exercise,
                    onPicked: (v) => setState(() => _exercise = v),
                  ),
                ),
                _PickerRow(
                  label: 'Zodiac',
                  value: _zodiac == null ? null : Zodiac.labels[_zodiac],
                  onTap: () => _pickSingle(
                    title: 'Zodiac sign',
                    labels: Zodiac.labels,
                    current: _zodiac,
                    onPicked: (v) => setState(() => _zodiac = v),
                  ),
                ),

                // ---- Interests ----
                const SizedBox(height: 28),
                _SectionHeader(
                  icon: Icons.interests_rounded,
                  title: 'Interests',
                  subtitle: 'Pick what you love. ${_interests.length} selected.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
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

  List<Widget> _buildPrompts() {
    final widgets = <Widget>[];
    for (var i = 0; i < _prompts.length; i++) {
      final p = _prompts[i];
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PromptCard(
            prompt: p,
            onEdit: () => _editPrompt(existing: p, index: i),
            onDelete: () => setState(() => _prompts.removeAt(i)),
          ),
        ),
      );
    }
    if (_prompts.length < 3) {
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => _editPrompt(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add a prompt'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: AppColors.textPrimary,
          ),
        ),
      );
    }
    return widgets;
  }
}

// =========================== shared widgets ===========================

class _PickerRow extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _PickerRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClayButton(
        onTap: onTap,
        borderRadius: 18,
        depth: 0.6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        color: Clay.surface(context),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value ?? 'Add',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: value == null
                      ? AppColors.textHint
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final PromptModel prompt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PromptCard({
    required this.prompt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      onTap: onEdit,
      borderRadius: 20,
      depth: 0.7,
      padding: const EdgeInsets.fromLTRB(18, 15, 8, 15),
      color: Clay.surface(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt.question,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  prompt.answer,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded,
                size: 20, color: AppColors.textHint),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet chrome: a handle, title, optional Clear action, and a child.
class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onClear;

  const _SheetScaffold({required this.title, required this.child, this.onClear});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (onClear != null)
                    TextButton(
                      onPressed: onClear,
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            child,
          ],
        ),
      ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String> current;
  final int max;
  final String Function(String)? display;

  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.max,
    this.display,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _selected = {...widget.current};

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '${widget.title} · ${_selected.length}/${widget.max}',
      child: Flexible(
        child: Column(
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: widget.options.map((opt) {
                  final sel = _selected.contains(opt);
                  return CheckboxListTile(
                    value: sel,
                    activeColor: AppColors.grape,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(
                      widget.display?.call(opt) ?? opt,
                      style: const TextStyle(
                          fontSize: 16, color: AppColors.textPrimary),
                    ),
                    onChanged: (_) {
                      setState(() {
                        if (sel) {
                          _selected.remove(opt);
                        } else if (_selected.length < widget.max) {
                          _selected.add(opt);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptEditorSheet extends StatefulWidget {
  final PromptModel? existing;
  const _PromptEditorSheet({this.existing});

  @override
  State<_PromptEditorSheet> createState() => _PromptEditorSheetState();
}

class _PromptEditorSheetState extends State<_PromptEditorSheet> {
  late String _question = widget.existing?.question ?? _promptQuestions.first;
  late final TextEditingController _answer =
      TextEditingController(text: widget.existing?.answer ?? '');

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _pickQuestion() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SheetScaffold(
        title: 'Choose a prompt',
        child: Flexible(
          child: ListView(
            shrinkWrap: true,
            children: _promptQuestions.map((q) {
              return ListTile(
                title: Text(q,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textPrimary)),
                trailing: q == _question
                    ? const Icon(Icons.check_rounded, color: AppColors.grape)
                    : null,
                onTap: () => Navigator.pop(ctx, q),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _question = picked);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _answer.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _SheetScaffold(
        title: 'Prompt',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClayButton(
                onTap: _pickQuestion,
                borderRadius: 16,
                depth: 0.55,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                color: Clay.surface(context),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _question,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answer,
                autofocus: true,
                maxLines: 3,
                maxLength: 225,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Your answer…'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSave
                      ? () => Navigator.pop(
                            context,
                            PromptModel(
                              question: _question,
                              answer: _answer.text.trim(),
                            ),
                          )
                      : null,
                  child: const Text('Save prompt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.grape],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LabelledField extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;

  const _LabelledField({
    required this.label,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final List<PhotoModel> photos;
  final bool isUploading;
  final VoidCallback onAdd;
  final void Function(PhotoModel) onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _PhotoStrip({
    required this.photos,
    required this.isUploading,
    required this.onAdd,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        onReorder: onReorder,
        proxyDecorator: (child, _, anim) => Material(
          color: Colors.transparent,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
        footer: Padding(
          padding: const EdgeInsets.only(left: 10, right: 4),
          child: _AddPhotoTile(
            onTap: isUploading ? null : onAdd,
            isUploading: isUploading,
          ),
        ),
        children: [
          for (var i = 0; i < photos.length; i++)
            Padding(
              key: ValueKey(photos[i].publicId),
              padding: const EdgeInsets.only(right: 10),
              child: _PhotoTile(
                photo: photos[i],
                isMain: i == 0,
                index: i,
                onDelete: () => onDelete(photos[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final PhotoModel photo;
  final bool isMain;
  final int index;
  final VoidCallback onDelete;

  const _PhotoTile({
    required this.photo,
    required this.isMain,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AppCachedImage(imageUrl: photo.url, fit: BoxFit.cover),
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (isMain)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    Icon(Icons.star_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Main',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
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
              onTap: onDelete,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
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
      child: ClayContainer(
        width: 110,
        height: 150,
        borderRadius: 20,
        depth: 0.7,
        pressed: true,
        alignment: Alignment.center,
        child: isUploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.primary),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.grape],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add photo',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              'Couldn\'t load profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
