// Phase 1.8 — repository unification. Consumes ReverseMatchApiClient.
//
// Wraps the `safety` API (report + block). No legacy model adaptation
// needed — both endpoints return 204.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(ref.read(apiClientProvider).safety);
});

class SafetyRepository {
  final api.SafetyApi _safety;

  SafetyRepository(this._safety);

  /// `reason` is the wire-value string from `ReportReason`
  /// (`harassment | spam | fake | inappropriate | underage | other`).
  Future<ApiResult<void>> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    try {
      final r = api.ReportReason.fromJson(reason) ?? api.ReportReason.other;
      await _safety.reportUser(
        api.ReportUserRequest(userId: userId, reason: r, details: details),
      );
      return const Success(null);
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to report user'),
      );
    }
  }

  Future<ApiResult<void>> blockUser(String userId) async {
    try {
      await _safety.blockUser(api.UserIdRequest(userId: userId));
      return const Success(null);
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to block user'),
      );
    }
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
