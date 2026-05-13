// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `messages`. Operations:
//   - GET  /messages/{matchId}      -> getMessages (page-paginated)
//   - POST /messages                -> sendMessage
//   - PUT  /messages/{matchId}/seen -> markMessagesSeen

import '../models/match_models.dart';
import '_base_api.dart';

final class MessagesApi extends BaseApi {
  MessagesApi(super.dio);

  Future<MessagesListResponse> getMessages(
    String matchId, {
    int? page,
    int? limit,
  }) async {
    final params = <String, dynamic>{
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };
    final response = await dio.get<dynamic>(
      '/messages/$matchId',
      queryParameters: params.isEmpty ? null : params,
    );
    return MessagesListResponse.fromJson(BaseApi.asJsonMap(response));
  }

  /// Returns the created [MessageModel] directly — NOT wrapped in `{ message }`.
  Future<MessageModel> sendMessage(SendMessageRequest body) async {
    final response = await dio.post<dynamic>(
      '/messages',
      data: body.toJson(),
    );
    return MessageModel.fromJson(BaseApi.asJsonMap(response));
  }

  Future<void> markMessagesSeen(String matchId) async {
    await dio.put<dynamic>('/messages/$matchId/seen');
  }
}
