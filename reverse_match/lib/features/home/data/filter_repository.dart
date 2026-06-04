// Loads/saves the girl's discovery filters via the shared Dio. We go through
// raw Dio (not the generated client) because the new preference fields
// (heightMin/heightMax/intent) aren't in the OpenAPI spec yet. Kept inside
// `data/` per the "no raw Dio outside data/" rule.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../domain/discovery_filters.dart';

final filterRepositoryProvider = Provider<FilterRepository>((ref) {
  return FilterRepository(ref.read(dioProvider));
});

class FilterRepository {
  final Dio _dio;

  FilterRepository(this._dio);

  /// Read the saved filters back out of `user.preferences`.
  Future<ApiResult<DiscoveryFilters>> load() async {
    try {
      final res = await _dio.get(ApiEndpoints.profile);
      final data = res.data;
      final prefs = (data is Map && data['preferences'] is Map)
          ? Map<String, dynamic>.from(data['preferences'] as Map)
          : <String, dynamic>{};
      return Success(DiscoveryFilters.fromPreferences(prefs));
    } on DioException catch (e) {
      return Failure(ServerException(_message(e) ?? 'Failed to load filters'));
    }
  }

  /// Persist the filters into `user.preferences`. The backend merges them and
  /// bumps the feed cache so the next feed/ideal-match reflects them.
  Future<ApiResult<void>> save(DiscoveryFilters filters) async {
    try {
      await _dio.put(
        ApiEndpoints.profile,
        data: {'preferences': filters.toPreferences()},
      );
      return const Success(null);
    } on DioException catch (e) {
      return Failure(ServerException(_message(e) ?? 'Failed to save filters'));
    }
  }

  String? _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final msg = (data['error'] as Map)['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return null;
  }
}
