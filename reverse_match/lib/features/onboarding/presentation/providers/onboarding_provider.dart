import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/onboarding_state.dart';

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingData>((ref) {
  return OnboardingController();
});

class OnboardingController extends StateNotifier<OnboardingData> {
  OnboardingController() : super(const OnboardingData());

  void setFirstName(String v) => state = state.copyWith(firstName: v);
  void setDob(DateTime v) => state = state.copyWith(dob: v);
  void setGender(String v) => state = state.copyWith(gender: v);
  void setGenderVisible(bool v) => state = state.copyWith(genderVisible: v);

  void setPronouns(List<String> v) => state = state.copyWith(pronouns: v);
  void setPronounsVisible(bool v) =>
      state = state.copyWith(pronounsVisible: v);
  void setOrientation(List<String> v) => state = state.copyWith(orientation: v);
  void setOrientationVisible(bool v) =>
      state = state.copyWith(orientationVisible: v);
  void setDatingPreference(String v) =>
      state = state.copyWith(datingPreference: v);
  void setDatingPreferenceVisible(bool v) =>
      state = state.copyWith(datingPreferenceVisible: v);
  void setEthnicityVisible(bool v) =>
      state = state.copyWith(ethnicityVisible: v);

  void setLocation({double? lat, double? lng, String? city}) {
    state = state.copyWith(latitude: lat, longitude: lng, city: city);
  }

  void setHeight(int cm) => state = state.copyWith(heightCm: cm);
  void setEthnicity(List<String> v) => state = state.copyWith(ethnicity: v);
  void setChildren(String v) => state = state.copyWith(children: v);
  void setFamilyPlans(String v) => state = state.copyWith(familyPlans: v);

  void setHometown(String v) => state = state.copyWith(hometown: v);
  void setJobTitle(String v) => state = state.copyWith(jobTitle: v);
  void setWorkplace(String v) => state = state.copyWith(workplace: v);
  void setEducation(String v) => state = state.copyWith(education: v);
  void setReligion(String v) => state = state.copyWith(religion: v);
  void setPolitics(String v) => state = state.copyWith(politics: v);
  void setLanguages(List<String> v) => state = state.copyWith(languages: v);
  void setDatingIntentions(String v) =>
      state = state.copyWith(datingIntentions: v);
  void setRelationshipType(String v) =>
      state = state.copyWith(relationshipType: v);

  void setInterests(List<String> v) => state = state.copyWith(interests: v);
  void setBio(String v) => state = state.copyWith(bio: v);
  void setExercise(String v) => state = state.copyWith(exercise: v);
  void setZodiac(String v) => state = state.copyWith(zodiac: v);

  void setDrinking(String v) => state = state.copyWith(drinking: v);
  void setSmoking(String v) => state = state.copyWith(smoking: v);
  void setMarijuana(String v) => state = state.copyWith(marijuana: v);
  void setDrugs(String v) => state = state.copyWith(drugs: v);

  void addPhoto(File f) =>
      state = state.copyWith(photos: [...state.photos, f]);
  void removePhoto(int i) {
    final list = [...state.photos]..removeAt(i);
    state = state.copyWith(photos: list);
  }

  void reorderPhotos(int oldIndex, int newIndex) {
    final list = [...state.photos];
    // ReorderableListView semantics: when moving down, newIndex is the
    // position AFTER removal of the dragged item, so we decrement.
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = list.removeAt(oldIndex);
    list.insert(adjusted, item);
    state = state.copyWith(photos: list);
  }

  void setPrompts(List<PromptAnswer> v) => state = state.copyWith(prompts: v);
  void setSelfie(File f) => state = state.copyWith(selfieFile: f);

  /// Maps UI labels → server enum values. Keys that aren't in the map are passed
  /// through (they're already in the right shape).
  static const _frequency = {
    'Yes': 'yes',
    'Sometimes': 'sometimes',
    'Rarely': 'rarely',
    'No': 'no',
    'Prefer not to say': 'prefer_not_to_say',
  };

  static const _children = {
    'Have children': 'have',
    "Don't have children": 'dont_have',
    'Prefer not to say': 'prefer_not_to_say',
  };

  static const _familyPlans = {
    'Want children': 'want',
    "Don't want children": 'dont_want',
    'Open to children': 'open',
    'Not sure yet': 'not_sure',
    'Prefer not to say': 'prefer_not_to_say',
  };

  static const _intentions = {
    'Life partner': 'life_partner',
    'Long-term relationship': 'long_term',
    'Long-term, open to short': 'long_term_open_short',
    'Short-term, open to long': 'short_term_open_long',
    'Short-term fun': 'short_term',
    'New friends': 'new_friends',
    'Still figuring it out': 'figuring_out',
  };

  static const _relationship = {
    'Monogamy': 'monogamy',
    'Non-monogamy': 'non_monogamy',
    'Open to exploring': 'open_to_exploring',
    'Prefer not to say': 'prefer_not_to_say',
  };

  static const _datingPreference = {
    'Men': 'men',
    'Women': 'women',
    'Everyone': 'everyone',
  };

  /// Builds the full payload for PUT /profile. Only includes fields the user
  /// actually set — unset fields are omitted so the server preserves existing values.
  Map<String, dynamic> backendPayload() {
    final s = state;
    final data = <String, dynamic>{};

    if (s.firstName.isNotEmpty) data['name'] = s.firstName;
    if (s.dob != null) data['dob'] = s.dob!.toUtc().toIso8601String();
    if (s.gender != null) data['gender'] = s.gender;

    if (s.pronouns.isNotEmpty) data['pronouns'] = s.pronouns;
    if (s.orientation.isNotEmpty) data['orientation'] = s.orientation;

    if (s.heightCm != null) data['height'] = s.heightCm;
    if (s.ethnicity.isNotEmpty) data['ethnicity'] = s.ethnicity;
    if (s.children != null) {
      data['children'] = _children[s.children] ?? s.children;
    }
    if (s.familyPlans != null) {
      data['familyPlans'] = _familyPlans[s.familyPlans] ?? s.familyPlans;
    }

    if (s.hometown.isNotEmpty) data['hometown'] = s.hometown;
    if (s.jobTitle.isNotEmpty) data['jobTitle'] = s.jobTitle;
    if (s.workplace.isNotEmpty) data['workplace'] = s.workplace;
    if (s.education.isNotEmpty) data['education'] = s.education;
    if (s.religion != null) data['religion'] = s.religion;
    if (s.politics != null) data['politics'] = s.politics;
    if (s.languages.isNotEmpty) data['languages'] = s.languages;

    if (s.datingIntentions != null) {
      data['datingIntentions'] =
          _intentions[s.datingIntentions] ?? s.datingIntentions;
    }
    if (s.relationshipType != null) {
      data['relationshipType'] =
          _relationship[s.relationshipType] ?? s.relationshipType;
    }

    if (s.interests.isNotEmpty) data['interests'] = s.interests;
    if (s.bio.trim().isNotEmpty) data['bio'] = s.bio.trim();
    if (s.exercise != null) data['exercise'] = s.exercise;
    if (s.zodiac != null) data['zodiac'] = s.zodiac;

    // The vice screens store the server KEY directly (e.g. 'yes'); older state
    // may hold a UI label. Map label→key when possible, else pass the value
    // through — never emit null (backend rejects non-string vice values).
    final vices = <String, dynamic>{};
    if (s.drinking != null) {
      vices['drinking'] = _frequency[s.drinking!] ?? s.drinking;
    }
    if (s.smoking != null) {
      vices['smoking'] = _frequency[s.smoking!] ?? s.smoking;
    }
    if (s.marijuana != null) {
      vices['marijuana'] = _frequency[s.marijuana!] ?? s.marijuana;
    }
    if (s.drugs != null) {
      vices['drugs'] = _frequency[s.drugs!] ?? s.drugs;
    }
    if (vices.isNotEmpty) data['vices'] = vices;

    if (s.prompts.isNotEmpty) {
      data['prompts'] = s.prompts
          .map((p) => {'question': p.question, 'answer': p.answer})
          .toList();
    }

    final prefs = <String, dynamic>{};
    if (s.datingPreference != null) {
      prefs['genderPreference'] =
          _datingPreference[s.datingPreference!] ?? s.datingPreference;
    }
    if (prefs.isNotEmpty) data['preferences'] = prefs;

    if (s.latitude != null && s.longitude != null) {
      data['location'] = {
        'coordinates': [s.longitude, s.latitude],
        if (s.city != null && s.city!.isNotEmpty) 'city': s.city,
      };
    }

    // Per-field "show on profile card?" toggles. Always sent so the backend
    // persists the user's choice (defaults to visible).
    data['visibility'] = {
      'gender': s.genderVisible,
      'orientation': s.orientationVisible,
      'ethnicity': s.ethnicityVisible,
      'pronouns': s.pronounsVisible,
      'datingPreference': s.datingPreferenceVisible,
    };

    return data;
  }
}
