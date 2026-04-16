class AppConstants {
  static const String appName = 'Reverse Match';
  static const int minPhotos = 2;
  static const int maxPhotos = 6;
  static const int maxBioLength = 300;
  static const int minAge = 18;
  static const int maxAge = 100;
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;
  static const int minInterests = 1;
  static const int feedPageSize = 20;
  static const int messagePageSize = 50;

  static const List<String> availableInterests = [
    'Music', 'Travel', 'Fitness', 'Movies', 'Gaming',
    'Food', 'Reading', 'Photography', 'Art', 'Sports',
    'Dancing', 'Cooking', 'Nature', 'Technology', 'Fashion',
    'Yoga', 'Pets', 'Netflix', 'Coffee', 'Adventure',
  ];
}
