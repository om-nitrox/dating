class UserModel {
  final String id;
  final String? email;
  final String? name;
  final int? age;
  final String? gender;
  final String? bio;
  final List<String> interests;
  final List<PhotoModel> photos;
  final LocationModel? location;
  final PreferencesModel? preferences;
  final int daysWithoutMatch;
  final String boostLevel;
  final bool isProfileComplete;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    this.email,
    this.name,
    this.age,
    this.gender,
    this.bio,
    this.interests = const [],
    this.photos = const [],
    this.location,
    this.preferences,
    this.daysWithoutMatch = 0,
    this.boostLevel = 'none',
    this.isProfileComplete = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'],
      name: json['name'],
      age: json['age'],
      gender: json['gender'],
      bio: json['bio'],
      interests: List<String>.from(json['interests'] ?? []),
      photos: (json['photos'] as List?)
              ?.map((p) => PhotoModel.fromJson(p))
              .toList() ??
          [],
      location: json['location'] != null
          ? LocationModel.fromJson(json['location'])
          : null,
      preferences: json['preferences'] != null
          ? PreferencesModel.fromJson(json['preferences'])
          : null,
      daysWithoutMatch: json['daysWithoutMatch'] ?? 0,
      boostLevel: json['boostLevel'] ?? 'none',
      isProfileComplete: json['isProfileComplete'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  String get firstPhoto =>
      photos.isNotEmpty ? photos.first.url : '';
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
    return LocationModel(
      coordinates: List<double>.from(
          json['coordinates']?.map((e) => (e as num).toDouble()) ?? [0, 0]),
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

  PreferencesModel({
    this.ageMin = 18,
    this.ageMax = 50,
    this.maxDistance = 50,
  });

  factory PreferencesModel.fromJson(Map<String, dynamic> json) {
    return PreferencesModel(
      ageMin: json['ageMin'] ?? 18,
      ageMax: json['ageMax'] ?? 50,
      maxDistance: json['maxDistance'] ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
        'ageMin': ageMin,
        'ageMax': ageMax,
        'maxDistance': maxDistance,
      };
}
