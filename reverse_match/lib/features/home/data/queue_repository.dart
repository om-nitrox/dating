// MIGRATED: Phase 0.2 — uses generated reverse_match_api client.
//
// Public signatures (`getQueue`, `accept`, `reject`) and the legacy
// `LikeModel` / `MatchModel` return types are unchanged so existing
// notifiers and screens continue to compile.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../shared/models/_api_adapters.dart';
import '../../../shared/models/like_model.dart';
import '../../../shared/models/match_model.dart';

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepository(ref.read(apiClientProvider));
});

class QueueRepository {
  final api.ReverseMatchApiClient _api;

  QueueRepository(this._api);

  Future<ApiResult<List<LikeModel>>> getQueue() async {
    try {
      final response = await _api.queue.getQueue();
      return Success(response.likes.map((l) => l.toLegacy()).toList());
    } on DioException catch (e) {
      return Failure(
          ServerException(_extractMessage(e) ?? 'Failed to load queue'));
    }
  }

  Future<ApiResult<MatchModel>> accept(String likeId) async {
    try {
      final response = await _api.queue.acceptLike(likeId);
      return Success(response.match.toLegacy());
    } on DioException catch (e) {
      return Failure(
          ServerException(_extractMessage(e) ?? 'Failed to accept'));
    }
  }

  Future<ApiResult<void>> reject(String likeId) async {
    try {
      await _api.queue.rejectLike(likeId);
      return const Success(null);
    } on DioException catch (e) {
      return Failure(
          ServerException(_extractMessage(e) ?? 'Failed to reject'));
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
