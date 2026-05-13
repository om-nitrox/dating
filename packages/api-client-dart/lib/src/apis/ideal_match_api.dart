// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `ideal-match`. Operations:
//   - GET /ideal-match -> getIdealMatch

import '../models/match_models.dart';
import '_base_api.dart';

final class IdealMatchApi extends BaseApi {
  IdealMatchApi(super.dio);

  Future<IdealMatchResponse> getIdealMatch({int? limit}) async {
    final response = await dio.get<dynamic>(
      '/ideal-match',
      queryParameters: limit != null ? {'limit': limit} : null,
    );
    return IdealMatchResponse.fromJson(BaseApi.asJsonMap(response));
  }
}
