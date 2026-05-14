// Phase 1.8 — repository unification. Consumes ReverseMatchApiClient.
//
// Wraps the `messages` API surface so the chat screen can stop talking to
// Dio directly. Returns legacy [MessageModel] (from `lib/shared/models/`)
// to keep widget/notifier code unchanged.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../shared/models/_api_adapters.dart';
import '../../../shared/models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(apiClientProvider).messages);
});

class ChatRepository {
  final api.MessagesApi _messages;

  ChatRepository(this._messages);

  /// Returns a page of messages for the given match.
  Future<ApiResult<MessagesPage>> getMessages(
    String matchId, {
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await _messages.getMessages(
        matchId,
        page: page,
        limit: limit,
      );
      return Success(
        MessagesPage(
          messages: response.messages.map((m) => m.toLegacy()).toList(),
          hasMore: response.hasMore,
        ),
      );
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to load messages'),
      );
    } catch (e) {
      return Failure(ServerException('Failed to parse messages: $e'));
    }
  }

  /// Send a new message. `idempotencyKey` is plumbed for the Phase 1.4
  /// backend work; until the generated client surfaces it, the value is
  /// ignored on the wire.
  ///
  /// TODO(phase-1.4): once `MessagesApi.sendMessage` accepts an
  /// `Idempotency-Key` header, forward `idempotencyKey` here.
  Future<ApiResult<MessageModel>> sendMessage({
    required String matchId,
    required String text,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _messages.sendMessage(
        api.SendMessageRequest(matchId: matchId, text: text),
      );
      return Success(response.toLegacy());
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to send message'),
      );
    }
  }

  Future<ApiResult<void>> markSeen(String matchId) async {
    try {
      await _messages.markMessagesSeen(matchId);
      return const Success(null);
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to mark seen'),
      );
    }
  }

  String? _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        final msg = err['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    }
    return null;
  }
}

/// Page of messages returned by [ChatRepository.getMessages]. Mirrors the
/// generated `MessagesListResponse` but adapted to legacy [MessageModel].
class MessagesPage {
  final List<MessageModel> messages;
  final bool hasMore;

  const MessagesPage({required this.messages, required this.hasMore});
}
