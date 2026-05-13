// MIGRATED: Phase 0.2 — uses generated reverse_match_api client.
//
// Public signatures (`getFeed`, `like`, `skip`, `undoLastSkip`) and the
// `FeedResult` shape are unchanged so the swipe screens and notifiers
// continue to compile.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../shared/models/_api_adapters.dart';
import '../../../shared/models/user_model.dart';

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository(ref.read(apiClientProvider));
});

class SwipeRepository {
  final api.ReverseMatchApiClient _api;

  SwipeRepository(this._api);

  Future<ApiResult<FeedResult>> getFeed({String? cursor}) async {
    try {
      final response = await _api.swipe.getSwipeFeed(cursor: cursor);
      return Success(FeedResult._fromApi(response));
    } on DioException catch (e) {
      return Failure(ServerException(
        _extractMessage(e) ?? 'Failed to load feed',
      ));
    } catch (e) {
      return Failure(ServerException('Failed to parse feed: $e'));
    }
  }

  Future<ApiResult<void>> like(String userId) async {
    try {
      await _api.swipe.likeUser(api.UserIdRequest(userId: userId));
      return const Success(null);
    } on DioException catch (e) {
      return Failure(ServerException(_extractMessage(e) ?? 'Failed to like'));
    }
  }

  Future<ApiResult<void>> skip(String userId) async {
    try {
      await _api.swipe.skipUser(api.UserIdRequest(userId: userId));
      return const Success(null);
    } on DioException catch (e) {
      return Failure(ServerException(_extractMessage(e) ?? 'Failed to skip'));
    }
  }

  Future<ApiResult<String>> undoLastSkip() async {
    try {
      final response = await _api.swipe.undoSkip();
      return Success(response.undoneUserId);
    } on DioException catch (e) {
      return Failure(
          ServerException(_extractMessage(e) ?? 'No skip to undo'));
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

class FeedResult {
  final List<UserModel> profiles;
  final String? nextCursor;

  FeedResult({required this.profiles, this.nextCursor});

  /// Adapt the generated `SwipeFeedResponse` to the legacy `FeedResult`.
  factory FeedResult._fromApi(api.SwipeFeedResponse response) {
    return FeedResult(
      profiles: response.profiles.map((u) => u.toLegacy()).toList(),
      nextCursor: response.nextCursor,
    );
  }

  /// Retained for any caller that still hand-rolls JSON parsing.
  factory FeedResult.fromJson(Map<String, dynamic> json) {
    return FeedResult(
      profiles: (json['profiles'] as List?)
              ?.map((p) => UserModel.fromJson(p))
              .toList() ??
          [],
      nextCursor: json['nextCursor'],
    );
  }
}
