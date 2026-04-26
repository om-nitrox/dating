class UserModel {
  final String id;
  final String? email;
  final String? name;
  final int? age;
  final DateTime? dob;
  final String? gender;
  final List<String> pronouns;
  final List<String> orientation;

  final String? bio;
  final List<String> interests;
  final List<PhotoModel> photos;
  final List<PromptModel> prompts;

  final int? height; // cm
  final List<String> ethnicity;
  final String? children;
  final String? familyPlans;

  final String? hometown;
  final String? jobTitle;
  final String? workplace;
  final String? education;
  final String? religion;
  final String? politics;
  final List<String> languages;
  final String? datingIntentions;
  final String? relationshipType;
  final VicesModel? vices;

  final LocationModel? location;
  final PreferencesModel? preferences;
  final int daysWithoutMatch;
  final String boostLevel;
  final bool isProfileComplete;
  final bool isVerified;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    this.email,
    this.name,
    this.age,
    this.dob,
    this.gender,
    this.pronouns = const [],
    this.orientation = const [],
    this.bio,
    this.interests = const [],
    this.photos = const [],
    this.prompts = const [],
    this.height,
    this.ethnicity = const [],
    this.children,
    this.familyPlans,
    this.hometown,
    this.jobTitle,
    this.workplace,
    this.education,
    this.religion,
    this.politics,
    this.languages = const [],
    this.datingIntentions,
    this.relationshipType,
    this.vices,
    this.location,
    this.preferences,
    this.daysWithoutMatch = 0,
    this.boostLevel = 'none',
    this.isProfileComplete = false,
    this.isVerified = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'],
      name: json['name'],
      age: json['age'],
      dob: json['dob'] != null ? DateTime.tryParse(json['dob']) : null,
      gender: json['gender'],
      pronouns: _stringList(json['pronouns']),
      orientation: _stringList(json['orientation']),
      bio: json['bio'],
      interests: _stringList(json['interests']),
      photos: (json['photos'] as List?)
              ?.map((p) => PhotoModel.fromJson(p))
              .toList() ??
          const [],
      prompts: (json['prompts'] as List?)
              ?.map((p) => PromptModel.fromJson(p))
              .toList() ??
          const [],
      height: json['height'],
      ethnicity: _stringList(json['ethnicity']),
      children: json['children'],
      familyPlans: json['familyPlans'],
      hometown: json['hometown'],
      jobTitle: json['jobTitle'],
      workplace: json['workplace'],
      education: json['education'],
      religion: json['religion'],
      politics: json['politics'],
      languages: _stringList(json['languages']),
      datingIntentions: json['datingIntentions'],
      relationshipType: json['relationshipType'],
      vices: json['vices'] != null ? VicesModel.fromJson(json['vices']) : null,
      location: json['location'] != null
          ? LocationModel.fromJson(json['location'])
          : null,
      preferences: json['preferences'] != null
          ? PreferencesModel.fromJson(json['preferences'])
          : null,
      daysWithoutMatch: json['daysWithoutMatch'] ?? 0,
      boostLevel: json['boostLevel'] ?? 'none',
      isProfileComplete: json['isProfileComplete'] ?? false,
      isVerified: json['isVerified'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  String get firstPhoto =>
      photos.isNotEmpty ? photos.first.url : '';

  /// Height in feet-inches for display, e.g. "5' 10"".
  String? get heightImperial {
    if (height == null) return null;
    final totalIn = (height! / 2.54).round();
    final ft = totalIn ~/ 12;
    final inch = totalIn % 12;
    return "$ft' $inch\"";
  }
}

class PhotoModel {
  final String url;
  final String publicId;

  PhotoModel({required this.url, required this.publicId});

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      url: json['url'] ?? '',
      publicId: json['publicId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'publicId': publicId};
}

class PromptModel {
  final String question;
  final String answer;

  const PromptModel({required this.question, required this.answer});

  factory PromptModel.fromJson(Map<String, dynamic> json) {
    return PromptModel(
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
      };
}

class VicesModel {
  final String? drinking;
  final String? smoking;
  final String? marijuana;
  final String? drugs;

  const VicesModel({this.drinking, this.smoking, this.marijuana, this.drugs});

  factory VicesModel.fromJson(Map<String, dynamic> json) {
    return VicesModel(
      drinking: json['drinking'],
      smoking: json['smoking'],
      marijuana: json['marijuana'],
      drugs: json['drugs'],
    );
  }

  Map<String, dynamic> toJson() => {
        if (drinking != null) 'drinking': drinking,
        if (smoking != null) 'smoking': smoking,
        if (marijuana != null) 'marijuana': marijuana,
        if (drugs != null) 'drugs': drugs,
      };
}

class LocationModel {
  final List<double> coordinates;
  final String? city;
  final String? state;

  LocationModel({
    this.coordinates = const [0, 0],
    this.city,
    this.state,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    final raw = json['coordinates'];
    final coords = raw is List
        ? raw.map((e) => (e as num).toDouble()).toList()
        : <double>[0.0, 0.0];
    return LocationModel(
      coordinates: coords,
      city: json['city'],
      state: json['state'],
    );
  }

  Map<String, dynamic> toJson() => {
        'coordinates': coordinates,
        'city': city,
        'state': state,
      };
}

class PreferencesModel {
  final int ageMin;
  final int ageMax;
  final int maxDistance;
  final String? genderPreference;

  PreferencesModel({
    this.ageMin = 18,
    this.ageMax = 50,
    this.maxDistance = 50,
    this.genderPreference,
  });

  factory PreferencesModel.fromJson(Map<String, dynamic> json) {
    return PreferencesModel(
      ageMin: json['ageMin'] ?? 18,
      ageMax: json['ageMax'] ?? 50,
      maxDistance: json['maxDistance'] ?? 50,
      genderPreference: json['genderPreference'],
    );
  }

  Map<String, dynamic> toJson() => {
        'ageMin': ageMin,
        'ageMax': ageMax,
        'maxDistance': maxDistance,
        if (genderPreference != null) 'genderPreference': genderPreference,
      };
}
