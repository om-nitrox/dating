// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Edit the spec, not this file.
//
// Covers: UserModel, Photo, Prompt, Vices, Location, Preferences,
// ProfileUpdateRequest, SelfieUploadResponse.

import '_helpers.dart';
import 'enums.dart';

/// `Photo` — Cloudinary delivery URL + publicId. Required: url, publicId.
class Photo {
  Photo({required this.url, required this.publicId});

  final String url;
  final String publicId;

  factory Photo.fromJson(Map<String, dynamic> json) => Photo(
        url: json['url'] as String? ?? '',
        publicId: json['publicId'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'publicId': publicId,
      };
}

/// `Prompt` — single profile prompt. Required: question, answer.
class Prompt {
  Prompt({required this.question, required this.answer});

  final String question;
  final String answer;

  factory Prompt.fromJson(Map<String, dynamic> json) => Prompt(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
      };
}

/// `Vices` — `additionalProperties: false`; each vice is independent + optional.
class Vices {
  Vices({this.drinking, this.smoking, this.marijuana, this.drugs});

  final ViceFrequency? drinking;
  final ViceFrequency? smoking;
  final ViceFrequency? marijuana;
  final ViceFrequency? drugs;

  factory Vices.fromJson(Map<String, dynamic> json) => Vices(
        drinking: ViceFrequency.fromJson(json['drinking']),
        smoking: ViceFrequency.fromJson(json['smoking']),
        marijuana: ViceFrequency.fromJson(json['marijuana']),
        drugs: ViceFrequency.fromJson(json['drugs']),
      );

  Map<String, dynamic> toJson() => {
        if (drinking != null) 'drinking': drinking!.toJson(),
        if (smoking != null) 'smoking': smoking!.toJson(),
        if (marijuana != null) 'marijuana': marijuana!.toJson(),
        if (drugs != null) 'drugs': drugs!.toJson(),
      };
}

/// `Location` — GeoJSON Point. `coordinates` is `[longitude, latitude]`.
class Location {
  Location({required this.coordinates, this.city, this.state});

  /// `[longitude, latitude]` — GeoJSON order. Backend enforces.
  final List<double> coordinates;
  final String? city;
  final String? state;

  factory Location.fromJson(Map<String, dynamic> json) {
    final raw = json['coordinates'];
    final coords = raw is List
        ? raw.map((e) => (e as num).toDouble()).toList(growable: false)
        : const <double>[0.0, 0.0];
    return Location(
      coordinates: coords,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'coordinates': coordinates,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
      };
}

/// `Preferences` — match filtering for the swipe feed.
class Preferences {
  Preferences({
    this.ageMin,
    this.ageMax,
    this.maxDistance,
    this.genderPreference,
  });

  final int? ageMin;
  final int? ageMax;
  final int? maxDistance;
  final GenderPreference? genderPreference;

  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        ageMin: coerceInt(json['ageMin']),
        ageMax: coerceInt(json['ageMax']),
        maxDistance: coerceInt(json['maxDistance']),
        genderPreference: GenderPreference.fromJson(json['genderPreference']),
      );

  Map<String, dynamic> toJson() => {
        if (ageMin != null) 'ageMin': ageMin,
        if (ageMax != null) 'ageMax': ageMax,
        if (maxDistance != null) 'maxDistance': maxDistance,
        if (genderPreference != null)
          'genderPreference': genderPreference!.toJson(),
      };
}

/// `UserModel` — canonical user shape. Only `_id` is required; everything
/// else is nullable on the wire. Server fills in defaults for arrays
/// (`pronouns`, `interests`, etc.) but we tolerate missing keys client-side
/// per the spec note.
class UserModel {
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
    this.exercise,
    this.zodiac,
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
    this.boostLevel = BoostLevel.none,
    this.isProfileComplete = false,
    this.isVerified = false,
    this.createdAt,
  });

  final String id;
  final String? email;
  final String? name;
  final int? age;
  final DateTime? dob;
  final Gender? gender;
  final List<String> pronouns;
  final List<String> orientation;
  final String? bio;
  final Exercise? exercise;
  final Zodiac? zodiac;
  final List<String> interests;
  final List<Photo> photos;
  final List<Prompt> prompts;
  final int? height;
  final List<String> ethnicity;
  final Children? children;
  final FamilyPlans? familyPlans;
  final String? hometown;
  final String? jobTitle;
  final String? workplace;
  final String? education;
  final String? religion;
  final Politics? politics;
  final List<String> languages;
  final DatingIntention? datingIntentions;
  final RelationshipType? relationshipType;
  final Vices? vices;
  final Location? location;
  final Preferences? preferences;
  final int daysWithoutMatch;
  final BoostLevel boostLevel;
  final bool isProfileComplete;
  final bool isVerified;
  final DateTime? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        // Spec note: both `_id` and `id` accepted, `_id` preferred.
        id: (json['_id'] ?? json['id'] ?? '') as String,
        email: json['email'] as String?,
        name: json['name'] as String?,
        age: coerceInt(json['age']),
        dob: parseIsoDate(json['dob']),
        gender: Gender.fromJson(json['gender']),
        pronouns: coerceStringList(json['pronouns']),
        orientation: coerceStringList(json['orientation']),
        bio: json['bio'] as String?,
        exercise: Exercise.fromJson(json['exercise']),
        zodiac: Zodiac.fromJson(json['zodiac']),
        interests: coerceStringList(json['interests']),
        photos: coerceList(json['photos'], Photo.fromJson),
        prompts: coerceList(json['prompts'], Prompt.fromJson),
        height: coerceInt(json['height']),
        ethnicity: coerceStringList(json['ethnicity']),
        children: Children.fromJson(json['children']),
        familyPlans: FamilyPlans.fromJson(json['familyPlans']),
        hometown: json['hometown'] as String?,
        jobTitle: json['jobTitle'] as String?,
        workplace: json['workplace'] as String?,
        education: json['education'] as String?,
        religion: json['religion'] as String?,
        politics: Politics.fromJson(json['politics']),
        languages: coerceStringList(json['languages']),
        datingIntentions: DatingIntention.fromJson(json['datingIntentions']),
        relationshipType: RelationshipType.fromJson(json['relationshipType']),
        vices: json['vices'] is Map<String, dynamic>
            ? Vices.fromJson(json['vices'] as Map<String, dynamic>)
            : null,
        location: json['location'] is Map<String, dynamic>
            ? Location.fromJson(json['location'] as Map<String, dynamic>)
            : null,
        preferences: json['preferences'] is Map<String, dynamic>
            ? Preferences.fromJson(json['preferences'] as Map<String, dynamic>)
            : null,
        daysWithoutMatch: coerceInt(json['daysWithoutMatch']) ?? 0,
        boostLevel: BoostLevel.fromJson(json['boostLevel']) ?? BoostLevel.none,
        isProfileComplete: json['isProfileComplete'] as bool? ?? false,
        isVerified: json['isVerified'] as bool? ?? false,
        createdAt: parseIsoDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (age != null) 'age': age,
        if (dob != null) 'dob': encodeIsoDate(dob),
        if (gender != null) 'gender': gender!.toJson(),
        'pronouns': pronouns,
        'orientation': orientation,
        if (bio != null) 'bio': bio,
        if (exercise != null) 'exercise': exercise!.toJson(),
        if (zodiac != null) 'zodiac': zodiac!.toJson(),
        'interests': interests,
        'photos': photos.map((p) => p.toJson()).toList(),
        'prompts': prompts.map((p) => p.toJson()).toList(),
        if (height != null) 'height': height,
        'ethnicity': ethnicity,
        if (children != null) 'children': children!.toJson(),
        if (familyPlans != null) 'familyPlans': familyPlans!.toJson(),
        if (hometown != null) 'hometown': hometown,
        if (jobTitle != null) 'jobTitle': jobTitle,
        if (workplace != null) 'workplace': workplace,
        if (education != null) 'education': education,
        if (religion != null) 'religion': religion,
        if (politics != null) 'politics': politics!.toJson(),
        'languages': languages,
        if (datingIntentions != null)
          'datingIntentions': datingIntentions!.toJson(),
        if (relationshipType != null)
          'relationshipType': relationshipType!.toJson(),
        if (vices != null) 'vices': vices!.toJson(),
        if (location != null) 'location': location!.toJson(),
        if (preferences != null) 'preferences': preferences!.toJson(),
        'daysWithoutMatch': daysWithoutMatch,
        'boostLevel': boostLevel.toJson(),
        'isProfileComplete': isProfileComplete,
        'isVerified': isVerified,
        if (createdAt != null) 'createdAt': encodeIsoDate(createdAt),
      };
}

/// `ProfileUpdateRequest` — PATCH-like; server drops unknown keys. The shape
/// matches `OnboardingController.backendPayload()` on the client. We keep it
/// as a plain map under the hood so callers can do partial updates without
/// instantiating defaults for every field.
class ProfileUpdateRequest {
  ProfileUpdateRequest({Map<String, dynamic>? fields})
      : _fields = fields ?? <String, dynamic>{};

  final Map<String, dynamic> _fields;

  set name(String? v) => _set('name', v);
  set dob(DateTime? v) => _set('dob', encodeIsoDate(v));
  set gender(Gender? v) => _set('gender', v?.toJson());
  set pronouns(List<String>? v) => _set('pronouns', v);
  set orientation(List<String>? v) => _set('orientation', v);
  set bio(String? v) => _set('bio', v);
  set exercise(Exercise? v) => _set('exercise', v?.toJson());
  set zodiac(Zodiac? v) => _set('zodiac', v?.toJson());
  set height(int? v) => _set('height', v);
  set ethnicity(List<String>? v) => _set('ethnicity', v);
  set children(Children? v) => _set('children', v?.toJson());
  set familyPlans(FamilyPlans? v) => _set('familyPlans', v?.toJson());
  set hometown(String? v) => _set('hometown', v);
  set jobTitle(String? v) => _set('jobTitle', v);
  set workplace(String? v) => _set('workplace', v);
  set education(String? v) => _set('education', v);
  set religion(String? v) => _set('religion', v);
  set politics(Politics? v) => _set('politics', v?.toJson());
  set languages(List<String>? v) => _set('languages', v);
  set datingIntentions(DatingIntention? v) =>
      _set('datingIntentions', v?.toJson());
  set relationshipType(RelationshipType? v) =>
      _set('relationshipType', v?.toJson());
  set vices(Vices? v) => _set('vices', v?.toJson());
  set prompts(List<Prompt>? v) =>
      _set('prompts', v?.map((p) => p.toJson()).toList());
  set preferences(Preferences? v) => _set('preferences', v?.toJson());
  set location(Location? v) => _set('location', v?.toJson());
  set interests(List<String>? v) => _set('interests', v);

  /// Set an arbitrary field — the spec allows `additionalProperties: true`.
  void setRaw(String key, Object? value) => _set(key, value);

  void _set(String key, Object? value) {
    if (value == null) {
      _fields.remove(key);
    } else {
      _fields[key] = value;
    }
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_fields);
}

/// `SelfieUploadResponse` — returned by `POST /profile/selfie`.
class SelfieUploadResponse {
  SelfieUploadResponse({required this.verified, required this.status});

  final bool verified;
  final SelfieReviewStatus status;

  factory SelfieUploadResponse.fromJson(Map<String, dynamic> json) =>
      SelfieUploadResponse(
        verified: json['verified'] as bool? ?? false,
        status: SelfieReviewStatus.fromJson(json['status']) ??
            SelfieReviewStatus.pendingReview,
      );

  Map<String, dynamic> toJson() => {
        'verified': verified,
        'status': status.toJson(),
      };
}
