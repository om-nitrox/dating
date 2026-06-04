// Verification + admin-review data layer.
//
// These calls carry fields (`role`, `selfieReviewStatus`,
// `selfieRejectionReason`) that are NOT in the generated OpenAPI client, so
// they go through the shared raw [Dio] (which already attaches the bearer
// token and handles refresh) and parse straight into the legacy [UserModel].

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/user_model.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return VerificationRepository(ref.read(dioProvider));
});

/// A girl awaiting admin approval, as shown in the verification queue. Carries
/// the selfie URL (not part of [UserModel]) so the admin can face-match.
class PendingProfile {
  final String id;
  final String name;
  final int? age;
  final String? bio;
  final List<String> photoUrls;
  final String? selfieUrl;

  PendingProfile({
    required this.id,
    required this.name,
    this.age,
    this.bio,
    this.photoUrls = const [],
    this.selfieUrl,
  });

  factory PendingProfile.fromJson(Map<String, dynamic> json) {
    final photos = json['photos'];
    final selfie = json['selfiePhoto'];
    return PendingProfile(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unnamed').toString(),
      age: json['age'] is int ? json['age'] as int : null,
      bio: json['bio'] as String?,
      photoUrls: photos is List
          ? photos
              .map((p) => (p is Map ? p['url'] : null)?.toString())
              .whereType<String>()
              .toList()
          : const [],
      selfieUrl: selfie is Map ? selfie['url'] as String? : null,
    );
  }
}

class VerificationRepository {
  final Dio _dio;

  VerificationRepository(this._dio);

  /// Fetch the full current-user profile, INCLUDING role + selfieReviewStatus.
  /// Used by the pending screen's poll and by auth startup hydration.
  Future<ApiResult<UserModel>> fetchMe() async {
    try {
      final res = await _dio.get(ApiEndpoints.profile);
      return Success(UserModel.fromJson(_unwrap(res.data)));
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to load profile'));
    }
  }

  // -------- Admin: verification queue --------

  Future<ApiResult<List<PendingProfile>>> listPending({int page = 1}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.adminPendingSelfies,
        queryParameters: {'page': page, 'limit': 20},
      );
      final data = res.data;
      final users = (data is Map ? data['users'] : null);
      final list = (users is List ? users : const [])
          .map((u) => PendingProfile.fromJson(Map<String, dynamic>.from(u)))
          .toList();
      return Success(list);
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to load verification queue'));
    }
  }

  Future<ApiResult<void>> approve(String userId) async {
    try {
      await _dio.post(ApiEndpoints.adminApproveSelfie(userId));
      return const Success(null);
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to approve profile'));
    }
  }

  Future<ApiResult<void>> reject(String userId, {String? reason}) async {
    try {
      await _dio.post(
        ApiEndpoints.adminRejectSelfie(userId),
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
      return const Success(null);
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to reject profile'));
    }
  }

  // GET /profile returns the user object directly; tolerate a `{ user: {...} }`
  // wrapper too in case the shape changes.
  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['user'] is Map) {
      return Map<String, dynamic>.from(data['user']);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  AppException _toException(DioException e, String fallback) {
    final message = _extractMessage(e) ?? fallback;
    final status = e.response?.statusCode;
    if (status == 401) return UnauthorizedException(message);
    return ServerException(message, status);
  }

  String? _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        final msg = err['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    }
    return null;
  }
}
