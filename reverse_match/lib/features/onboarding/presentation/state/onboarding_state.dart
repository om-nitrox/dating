import 'dart:io';

class OnboardingData {
  // Backend-wired
  final String firstName;
  final DateTime? dob;
  final String? gender; // 'male' | 'female' | 'nonbinary'
  final bool genderVisible;
  final bool orientationVisible;
  final bool ethnicityVisible;
  final bool pronounsVisible;
  final bool datingPreferenceVisible;
  final List<File> photos;
  final String? city;
  final double? latitude;
  final double? longitude;

  // Dummy (frontend only for now)
  final List<String> pronouns;
  final List<String> orientation;
  final String? datingPreference;

  final int? heightCm;
  final List<String> ethnicity;
  final String? children;
  final String? familyPlans;

  final String hometown;
  final String jobTitle;
  final String workplace;
  final String education;
  final String? religion;
  final String? politics;
  final List<String> languages;
  final String? datingIntentions;
  final String? relationshipType;

  // Profile content (wired to PUT /profile)
  final List<String> interests;
  final String bio;
  final String? exercise;
  final String? zodiac;

  final String? drinking;
  final String? smoking;
  final String? marijuana;
  final String? drugs;

  final List<PromptAnswer> prompts;
  final File? selfieFile;

  const OnboardingData({
    this.firstName = '',
    this.dob,
    this.gender,
    this.genderVisible = true,
    this.orientationVisible = true,
    this.ethnicityVisible = true,
    this.pronounsVisible = true,
    this.datingPreferenceVisible = false,
    this.photos = const [],
    this.city,
    this.latitude,
    this.longitude,
    this.pronouns = const [],
    this.orientation = const [],
    this.datingPreference,
    this.heightCm,
    this.ethnicity = const [],
    this.children,
    this.familyPlans,
    this.hometown = '',
    this.jobTitle = '',
    this.workplace = '',
    this.education = '',
    this.religion,
    this.politics,
    this.languages = const [],
    this.datingIntentions,
    this.relationshipType,
    this.interests = const [],
    this.bio = '',
    this.exercise,
    this.zodiac,
    this.drinking,
    this.smoking,
    this.marijuana,
    this.drugs,
    this.prompts = const [],
    this.selfieFile,
  });

  int? get age {
    if (dob == null) return null;
    final now = DateTime.now();
    var a = now.year - dob!.year;
    if (now.month < dob!.month ||
        (now.month == dob!.month && now.day < dob!.day)) {
      a--;
    }
    return a;
  }

  OnboardingData copyWith({
    String? firstName,
    DateTime? dob,
    String? gender,
    bool? genderVisible,
    bool? orientationVisible,
    bool? ethnicityVisible,
    bool? pronounsVisible,
    bool? datingPreferenceVisible,
    List<File>? photos,
    String? city,
    double? latitude,
    double? longitude,
    List<String>? pronouns,
    List<String>? orientation,
    String? datingPreference,
    int? heightCm,
    List<String>? ethnicity,
    String? children,
    String? familyPlans,
    String? hometown,
    String? jobTitle,
    String? workplace,
    String? education,
    String? religion,
    String? politics,
    List<String>? languages,
    String? datingIntentions,
    String? relationshipType,
    List<String>? interests,
    String? bio,
    String? exercise,
    String? zodiac,
    String? drinking,
    String? smoking,
    String? marijuana,
    String? drugs,
    List<PromptAnswer>? prompts,
    File? selfieFile,
  }) {
    return OnboardingData(
      firstName: firstName ?? this.firstName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      genderVisible: genderVisible ?? this.genderVisible,
      orientationVisible: orientationVisible ?? this.orientationVisible,
      ethnicityVisible: ethnicityVisible ?? this.ethnicityVisible,
      pronounsVisible: pronounsVisible ?? this.pronounsVisible,
      datingPreferenceVisible:
          datingPreferenceVisible ?? this.datingPreferenceVisible,
      photos: photos ?? this.photos,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pronouns: pronouns ?? this.pronouns,
      orientation: orientation ?? this.orientation,
      datingPreference: datingPreference ?? this.datingPreference,
      heightCm: heightCm ?? this.heightCm,
      ethnicity: ethnicity ?? this.ethnicity,
      children: children ?? this.children,
      familyPlans: familyPlans ?? this.familyPlans,
      hometown: hometown ?? this.hometown,
      jobTitle: jobTitle ?? this.jobTitle,
      workplace: workplace ?? this.workplace,
      education: education ?? this.education,
      religion: religion ?? this.religion,
      politics: politics ?? this.politics,
      languages: languages ?? this.languages,
      datingIntentions: datingIntentions ?? this.datingIntentions,
      relationshipType: relationshipType ?? this.relationshipType,
      interests: interests ?? this.interests,
      bio: bio ?? this.bio,
      exercise: exercise ?? this.exercise,
      zodiac: zodiac ?? this.zodiac,
      drinking: drinking ?? this.drinking,
      smoking: smoking ?? this.smoking,
      marijuana: marijuana ?? this.marijuana,
      drugs: drugs ?? this.drugs,
      prompts: prompts ?? this.prompts,
      selfieFile: selfieFile ?? this.selfieFile,
    );
  }
}

class PromptAnswer {
  final String question;
  final String answer;

  const PromptAnswer({required this.question, required this.answer});
}
