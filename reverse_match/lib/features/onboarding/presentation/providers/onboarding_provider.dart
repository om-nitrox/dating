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

  void setPronouns(List<String> v) => state = state.copyWith(pronouns: v);
  void setOrientation(List<String> v) => state = state.copyWith(orientation: v);
  void setDatingPreference(String v) =>
      state = state.copyWith(datingPreference: v);

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

    final vices = <String, dynamic>{};
    if (s.drinking != null) vices['drinking'] = _frequency[s.drinking!];
    if (s.smoking != null) vices['smoking'] = _frequency[s.smoking!];
    if (s.marijuana != null) vices['marijuana'] = _frequency[s.marijuana!];
    if (s.drugs != null) vices['drugs'] = _frequency[s.drugs!];
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

    return data;
  }
}
