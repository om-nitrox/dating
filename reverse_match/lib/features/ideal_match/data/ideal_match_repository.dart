// Ideal Match (girls-only) repository.
//
// The status/reveal endpoints are not in the generated OpenAPI client yet,
// so this goes through the shared Dio (allowed inside `data/`). `status` is a
// pure read for the gate UI; `reveal` runs the ML model and spends one of the
// two weekly uses.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/user_model.dart';

final idealMatchRepositoryProvider = Provider<IdealMatchRepository>((ref) {
  return IdealMatchRepository(ref.read(dioProvider));
});

class IdealMatchRepository {
  final Dio _dio;
  IdealMatchRepository(this._dio);

  Future<ApiResult<IdealMatchStatus>> getStatus() async {
    try {
      final res = await _dio.get(ApiEndpoints.idealMatchStatus);
      return Success(
          IdealMatchStatus.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to load Ideal Match'));
    }
  }

  Future<ApiResult<IdealMatchResult>> reveal() async {
    try {
      final res = await _dio.post(ApiEndpoints.idealMatchReveal);
      return Success(
          IdealMatchResult.fromJson(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Failure(_toException(e, 'Could not find your ideal match'));
    }
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

class IdealMatchStatus {
  final bool eligible;
  final int swipeCount;
  final int minSwipes;
  final double completion;
  final double completionThreshold;
  final int usesThisWeek;
  final int weeklyCap;
  final DateTime? nextResetAt;
  final bool swipesOk;
  final bool profileOk;
  final bool capOk;

  IdealMatchStatus({
    required this.eligible,
    required this.swipeCount,
    required this.minSwipes,
    required this.completion,
    required this.completionThreshold,
    required this.usesThisWeek,
    required this.weeklyCap,
    required this.nextResetAt,
    required this.swipesOk,
    required this.profileOk,
    required this.capOk,
  });

  int get swipesLeft => (minSwipes - swipeCount).clamp(0, minSwipes);
  int get usesLeft => (weeklyCap - usesThisWeek).clamp(0, weeklyCap);
  int get completionPercent => (completion * 100).round();
  int get completionThresholdPercent => (completionThreshold * 100).round();

  factory IdealMatchStatus.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int i(dynamic v) => (v is num) ? v.toInt() : 0;
    return IdealMatchStatus(
      eligible: json['eligible'] == true,
      swipeCount: i(json['swipeCount']),
      minSwipes: i(json['minSwipes']),
      completion: d(json['completion']),
      completionThreshold: d(json['completionThreshold']),
      usesThisWeek: i(json['usesThisWeek']),
      weeklyCap: i(json['weeklyCap']),
      nextResetAt: json['nextResetAt'] != null
          ? DateTime.tryParse(json['nextResetAt'].toString())
          : null,
      swipesOk: json['swipesOk'] == true,
      profileOk: json['profileOk'] == true,
      capOk: json['capOk'] == true,
    );
  }
}

class IdealMatchResult {
  final UserModel match;
  final double score;
  final List<String> commonalities;
  final int usesThisWeek;
  final int weeklyCap;

  IdealMatchResult({
    required this.match,
    required this.score,
    required this.commonalities,
    required this.usesThisWeek,
    required this.weeklyCap,
  });

  int get scorePercent => (score * 100).round();

  factory IdealMatchResult.fromJson(Map<String, dynamic> json) {
    return IdealMatchResult(
      match: UserModel.fromJson(json['topMatch'] as Map<String, dynamic>),
      score: (json['score'] is num) ? (json['score'] as num).toDouble() : 0.0,
      commonalities: (json['commonalities'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      usesThisWeek: (json['usesThisWeek'] is num)
          ? (json['usesThisWeek'] as num).toInt()
          : 0,
      weeklyCap:
          (json['weeklyCap'] is num) ? (json['weeklyCap'] as num).toInt() : 2,
    );
  }
}
