// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `swipe`. Operations:
//   - GET  /swipe/feed -> getSwipeFeed (cursor-paginated)
//   - POST /swipe/like -> likeUser
//   - POST /swipe/skip -> skipUser
//   - POST /swipe/undo -> undoSkip

import 'package:dio/dio.dart';

import '../models/enums.dart';
import '../models/match_models.dart';
import '../models/misc_models.dart';
import '_base_api.dart';

final class SwipeApi extends BaseApi {
  SwipeApi(super.dio);

  Future<SwipeFeedResponse> getSwipeFeed({
    String? cursor,
    int? minAge,
    int? maxAge,
    int? maxDistanceKm,
    DatingIntention? intent,
  }) async {
    final params = <String, dynamic>{
      if (cursor != null) 'cursor': cursor,
      if (minAge != null) 'minAge': minAge,
      if (maxAge != null) 'maxAge': maxAge,
      if (maxDistanceKm != null) 'maxDistanceKm': maxDistanceKm,
      if (intent != null) 'intent': intent.toJson(),
    };
    final response = await dio.get<dynamic>(
      '/swipe/feed',
      queryParameters: params.isEmpty ? null : params,
    );
    return SwipeFeedResponse.fromJson(BaseApi.asJsonMap(response));
  }

  Future<void> likeUser(UserIdRequest body) async {
    await dio.post<dynamic>('/swipe/like', data: body.toJson());
  }

  Future<void> skipUser(UserIdRequest body) async {
    await dio.post<dynamic>('/swipe/skip', data: body.toJson());
  }

  Future<UndoSkipResponse> undoSkip() async {
    final response = await dio.post<dynamic>('/swipe/undo');
    return UndoSkipResponse.fromJson(BaseApi.asJsonMap(response));
  }
}
