// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `account`. Operations:
//   - DELETE /account -> deleteAccount

import '../models/misc_models.dart';
import '_base_api.dart';

final class AccountApi extends BaseApi {
  AccountApi(super.dio);

  Future<void> deleteAccount(AccountDeleteRequest body) async {
    await dio.delete<dynamic>('/account', data: body.toJson());
  }
}
