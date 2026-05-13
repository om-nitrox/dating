// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `queue`. Operations:
//   - GET  /queue                     -> getQueue (page-paginated)
//   - POST /queue/accept/{likeId}     -> acceptLike
//   - POST /queue/reject/{likeId}     -> rejectLike

import '../models/match_models.dart';
import '../models/misc_models.dart';
import '_base_api.dart';

final class QueueApi extends BaseApi {
  QueueApi(super.dio);

  Future<QueueListResponse> getQueue({int? page, int? limit}) async {
    final params = <String, dynamic>{
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };
    final response = await dio.get<dynamic>(
      '/queue',
      queryParameters: params.isEmpty ? null : params,
    );
    return QueueListResponse.fromJson(BaseApi.asJsonMap(response));
  }

  Future<AcceptLikeResponse> acceptLike(String likeId) async {
    final response = await dio.post<dynamic>('/queue/accept/$likeId');
    return AcceptLikeResponse.fromJson(BaseApi.asJsonMap(response));
  }

  Future<void> rejectLike(String likeId) async {
    await dio.post<dynamic>('/queue/reject/$likeId');
  }
}
