// Phase 1.8 — repository unification. Consumes ReverseMatchApiClient.
//
// Wraps the `matches` API surface. Returns legacy [MatchModel] to keep the
// matches screen and its notifier compatible.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../shared/models/_api_adapters.dart';
import '../../../shared/models/match_model.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(ref.read(apiClientProvider).matches);
});

class MatchRepository {
  final api.MatchesApi _matches;

  MatchRepository(this._matches);

  Future<ApiResult<MatchesPage>> listMatches({
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await _matches.listMatches(page: page, limit: limit);
      return Success(
        MatchesPage(
          matches: response.matches.map((m) => m.toLegacy()).toList(),
          hasMore: response.hasMore,
        ),
      );
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to load matches'),
      );
    }
  }

  Future<ApiResult<void>> unmatch(String matchId) async {
    try {
      await _matches.unmatch(matchId);
      return const Success(null);
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to unmatch'),
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

/// Adapted form of `MatchesListResponse`.
class MatchesPage {
  final List<MatchModel> matches;
  final bool hasMore;

  const MatchesPage({required this.matches, required this.hasMore});
}
