// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `safety`. Operations:
//   - POST /report -> reportUser
//   - POST /block  -> blockUser

import '../models/misc_models.dart';
import '_base_api.dart';

final class SafetyApi extends BaseApi {
  SafetyApi(super.dio);

  Future<void> reportUser(ReportUserRequest body) async {
    await dio.post<dynamic>('/report', data: body.toJson());
  }

  Future<void> blockUser(UserIdRequest body) async {
    await dio.post<dynamic>('/block', data: body.toJson());
  }
}
