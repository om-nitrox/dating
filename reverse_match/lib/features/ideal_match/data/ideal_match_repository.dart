// Phase 1.8 — repository unification. Consumes ReverseMatchApiClient.
//
// The `IdealMatchResponse` has no legacy equivalent yet — there's no UI
// for it pre-Phase-1.8. We return the generated model directly. Once the
// UI lands, define a legacy `IdealMatchModel` in `lib/shared/models/` and
// adapt here.
//
// Phase 1.8 TODO: define legacy IdealMatchModel or migrate UI to consume
// the generated model directly.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';

final idealMatchRepositoryProvider = Provider<IdealMatchRepository>((ref) {
  return IdealMatchRepository(ref.read(apiClientProvider).idealMatch);
});

class IdealMatchRepository {
  final api.IdealMatchApi _idealMatch;

  IdealMatchRepository(this._idealMatch);

  Future<ApiResult<api.IdealMatchResponse>> getIdealMatch({int? limit}) async {
    try {
      final response = await _idealMatch.getIdealMatch(limit: limit);
      return Success(response);
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to load ideal match'),
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
