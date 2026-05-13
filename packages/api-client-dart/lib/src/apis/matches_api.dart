// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `matches`. Operations:
//   - GET    /matches             -> listMatches (page-paginated)
//   - DELETE /matches/{matchId}   -> unmatch

import '../models/match_models.dart';
import '_base_api.dart';

final class MatchesApi extends BaseApi {
  MatchesApi(super.dio);

  Future<MatchesListResponse> listMatches({int? page, int? limit}) async {
    final params = <String, dynamic>{
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };
    final response = await dio.get<dynamic>(
      '/matches',
      queryParameters: params.isEmpty ? null : params,
    );
    return MatchesListResponse.fromJson(BaseApi.asJsonMap(response));
  }

  Future<void> unmatch(String matchId) async {
    await dio.delete<dynamic>('/matches/$matchId');
  }
}
