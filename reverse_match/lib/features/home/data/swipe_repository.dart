import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/user_model.dart';

final swipeRepositoryProvider = Provider<SwipeRepository>((ref) {
  return SwipeRepository(ref.read(dioProvider));
});

class SwipeRepository {
  final Dio _dio;

  SwipeRepository(this._dio);

  Future<ApiResult<FeedResult>> getFeed({String? cursor}) async {
    try {
      final params = <String, dynamic>{};
      if (cursor != null) params['cursor'] = cursor;
      final response =
          await _dio.get(ApiEndpoints.feed, queryParameters: params);
      return Success(FeedResult.fromJson(response.data));
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to load feed',
      ));
    } catch (e) {
      return Failure(ServerException('Failed to parse feed: $e'));
    }
  }

  Future<ApiResult<void>> like(String userId) async {
    try {
      await _dio.post(ApiEndpoints.like, data: {'userId': userId});
      return const Success(null);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to like',
      ));
    }
  }

  Future<ApiResult<void>> skip(String userId) async {
    try {
      await _dio.post(ApiEndpoints.skip, data: {'userId': userId});
      return const Success(null);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to skip',
      ));
    }
  }

  Future<ApiResult<String>> undoLastSkip() async {
    try {
      final response = await _dio.post(ApiEndpoints.undoSkip);
      return Success(response.data['undoneUserId'] ?? '');
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'No skip to undo',
      ));
    }
  }
}

class FeedResult {
  final List<UserModel> profiles;
  final String? nextCursor;

  FeedResult({required this.profiles, this.nextCursor});

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
