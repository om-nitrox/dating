import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/like_model.dart';
import '../../../shared/models/match_model.dart';

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepository(ref.read(dioProvider));
});

class QueueRepository {
  final Dio _dio;

  QueueRepository(this._dio);

  Future<ApiResult<List<LikeModel>>> getQueue() async {
    try {
      final response = await _dio.get(ApiEndpoints.queue);
      final likes = (response.data['likes'] as List?)
              ?.map((l) => LikeModel.fromJson(l))
              .toList() ??
          [];
      return Success(likes);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to load queue',
      ));
    }
  }

  Future<ApiResult<MatchModel>> accept(String likeId) async {
    try {
      final response = await _dio.post(ApiEndpoints.acceptLike(likeId));
      return Success(MatchModel.fromJson(response.data['match']));
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to accept',
      ));
    }
  }

  Future<ApiResult<void>> reject(String likeId) async {
    try {
      await _dio.post(ApiEndpoints.rejectLike(likeId));
      return const Success(null);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to reject',
      ));
    }
  }
}
