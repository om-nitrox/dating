// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `config`. Operations:
//   - GET /config -> getConfig (unauthenticated)

import '../models/misc_models.dart';
import '_base_api.dart';

final class ConfigApi extends BaseApi {
  ConfigApi(super.dio);

  Future<AppConfig> getConfig() async {
    final response = await dio.get<dynamic>('/config');
    return AppConfig.fromJson(BaseApi.asJsonMap(response));
  }
}
