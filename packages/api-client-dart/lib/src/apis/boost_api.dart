// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `boost`. Operations:
//   - GET  /boost/plans    -> listBoostPlans
//   - GET  /boost/status   -> getBoostStatus
//   - POST /boost/purchase -> purchaseBoost

import '../models/boost_models.dart';
import '_base_api.dart';

final class BoostApi extends BaseApi {
  BoostApi(super.dio);

  Future<BoostPlansResponse> listBoostPlans() async {
    final response = await dio.get<dynamic>('/boost/plans');
    return BoostPlansResponse.fromJson(BaseApi.asJsonMap(response));
  }

  Future<BoostStatusModel> getBoostStatus() async {
    final response = await dio.get<dynamic>('/boost/status');
    return BoostStatusModel.fromJson(BaseApi.asJsonMap(response));
  }

  Future<BoostPurchaseResponse> purchaseBoost(
      BoostPurchaseRequest body) async {
    final response = await dio.post<dynamic>(
      '/boost/purchase',
      data: body.toJson(),
    );
    return BoostPurchaseResponse.fromJson(BaseApi.asJsonMap(response));
  }
}
