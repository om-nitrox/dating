import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api/v1';
  static String get socketUrl => dotenv.env['SOCKET_URL'] ?? 'http://localhost:5000';

  // Auth
  static const String signup = '/auth/signup';
  static const String verifyOtp = '/auth/verify-otp';
  static const String googleAuth = '/auth/google';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';

  // Profile
  static const String profile = '/profile';
  static const String uploadPhotos = '/profile/photos';
  static String deletePhoto(String publicId) => '/profile/photos/$publicId';

  // Swipe (girls)
  static const String feed = '/swipe/feed';
  static const String like = '/swipe/like';
  static const String skip = '/swipe/skip';
  static const String undoSkip = '/swipe/undo';

  // Queue (boys)
  static const String queue = '/queue';
  static String acceptLike(String likeId) => '/queue/accept/$likeId';
  static String rejectLike(String likeId) => '/queue/reject/$likeId';

  // Matches
  static const String matches = '/matches';
  static String deleteMatch(String matchId) => '/matches/$matchId';

  // Messages
  static String messages(String matchId) => '/messages/$matchId';
  static const String sendMessage = '/messages';
  static String markSeen(String matchId) => '/messages/$matchId/seen';

  // Boost
  static const String boostPlans = '/boost/plans';
  static const String purchaseBoost = '/boost/purchase';
  static const String boostStatus = '/boost/status';

  // Profile photos
  static const String reorderPhotos = '/profile/photos/reorder';

  // Config
  static const String appConfig = '/config';

  // Safety
  static const String report = '/report';
  static const String block = '/block';

  // Account
  static const String deleteAccount = '/account';
}
