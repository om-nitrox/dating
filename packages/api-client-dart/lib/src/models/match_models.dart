// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Covers Match, Message, Like, list wrappers, and ideal-match response.

import '_helpers.dart';
import 'enums.dart';
import 'user_models.dart';

/// `MessageModel` — full message row. Required: _id, matchId, sender, text, seen, createdAt.
class MessageModel {
  MessageModel({
    required this.id,
    required this.matchId,
    required this.sender,
    required this.text,
    required this.seen,
    required this.createdAt,
  });

  final String id;
  final String matchId;
  final String sender;
  final String text;
  final bool seen;
  final DateTime createdAt;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: (json['_id'] ?? json['id'] ?? '') as String,
        matchId: json['matchId'] as String? ?? '',
        sender: json['sender'] as String? ?? '',
        text: json['text'] as String? ?? '',
        seen: json['seen'] as bool? ?? false,
        createdAt: parseIsoDate(json['createdAt']) ?? DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'matchId': matchId,
        'sender': sender,
        'text': text,
        'seen': seen,
        'createdAt': encodeIsoDate(createdAt),
      };
}

/// `MatchModel` — required: _id, users (length 2), unreadCount, createdAt.
/// `lastMessage` is `oneOf: [MessageModel, null]`.
class MatchModel {
  MatchModel({
    required this.id,
    required this.users,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
  });

  final String id;
  final List<UserModel> users;
  final MessageModel? lastMessage;
  final int unreadCount;
  final DateTime createdAt;

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return MatchModel(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      users: coerceList(json['users'], UserModel.fromJson),
      lastMessage: last is Map<String, dynamic>
          ? MessageModel.fromJson(last)
          : (last is Map ? MessageModel.fromJson(Map<String, dynamic>.from(last)) : null),
      unreadCount: coerceInt(json['unreadCount']) ?? 0,
      createdAt: parseIsoDate(json['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'users': users.map((u) => u.toJson()).toList(),
        'lastMessage': lastMessage?.toJson(),
        'unreadCount': unreadCount,
        'createdAt': encodeIsoDate(createdAt),
      };

  /// Convenience: the other participant in the match.
  UserModel otherUser(String myId) {
    return users.firstWhere(
      (u) => u.id != myId,
      orElse: () => users.first,
    );
  }
}

/// `LikeModel` — pending/accepted/rejected like. Required: _id, fromUser,
/// status, type, createdAt.
class LikeModel {
  LikeModel({
    required this.id,
    required this.fromUser,
    required this.status,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final UserModel fromUser;
  final LikeStatus status;
  final LikeType type;
  final DateTime createdAt;

  factory LikeModel.fromJson(Map<String, dynamic> json) => LikeModel(
        id: (json['_id'] ?? json['id'] ?? '') as String,
        fromUser: UserModel.fromJson(
          Map<String, dynamic>.from(json['fromUser'] as Map),
        ),
        status: LikeStatus.fromJson(json['status']) ?? LikeStatus.pending,
        type: LikeType.fromJson(json['type']) ?? LikeType.like,
        createdAt: parseIsoDate(json['createdAt']) ?? DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'fromUser': fromUser.toJson(),
        'status': status.toJson(),
        'type': type.toJson(),
        'createdAt': encodeIsoDate(createdAt),
      };
}

/// `SwipeFeedResponse` — wraps a feed page + opaque `nextCursor`.
class SwipeFeedResponse {
  SwipeFeedResponse({required this.profiles, this.nextCursor});

  final List<UserModel> profiles;
  final String? nextCursor;

  factory SwipeFeedResponse.fromJson(Map<String, dynamic> json) =>
      SwipeFeedResponse(
        profiles: coerceList(json['profiles'], UserModel.fromJson),
        nextCursor: json['nextCursor'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'nextCursor': nextCursor,
      };
}

/// `MatchesListResponse` — page-paginated matches.
class MatchesListResponse {
  MatchesListResponse({required this.matches, required this.hasMore});

  final List<MatchModel> matches;
  final bool hasMore;

  factory MatchesListResponse.fromJson(Map<String, dynamic> json) =>
      MatchesListResponse(
        matches: coerceList(json['matches'], MatchModel.fromJson),
        hasMore: json['hasMore'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'matches': matches.map((m) => m.toJson()).toList(),
        'hasMore': hasMore,
      };
}

/// `QueueListResponse` — page-paginated incoming likes.
class QueueListResponse {
  QueueListResponse({required this.likes, required this.hasMore});

  final List<LikeModel> likes;
  final bool hasMore;

  factory QueueListResponse.fromJson(Map<String, dynamic> json) =>
      QueueListResponse(
        likes: coerceList(json['likes'], LikeModel.fromJson),
        hasMore: json['hasMore'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'likes': likes.map((l) => l.toJson()).toList(),
        'hasMore': hasMore,
      };
}

/// `MessagesListResponse` — page-paginated message history.
class MessagesListResponse {
  MessagesListResponse({required this.messages, required this.hasMore});

  final List<MessageModel> messages;
  final bool hasMore;

  factory MessagesListResponse.fromJson(Map<String, dynamic> json) =>
      MessagesListResponse(
        messages: coerceList(json['messages'], MessageModel.fromJson),
        hasMore: json['hasMore'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'messages': messages.map((m) => m.toJson()).toList(),
        'hasMore': hasMore,
      };
}

/// `IdealMatchAlternate` — one of the `n-1` alternates returned by /ideal-match.
class IdealMatchAlternate {
  IdealMatchAlternate({required this.user, required this.score});

  final UserModel user;
  final double score;

  factory IdealMatchAlternate.fromJson(Map<String, dynamic> json) =>
      IdealMatchAlternate(
        user: UserModel.fromJson(
          Map<String, dynamic>.from(json['user'] as Map),
        ),
        score: coerceDouble(json['score']) ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'score': score,
      };
}

/// `IdealMatchResponse` — top match + alternates + pre-computed commonalities.
class IdealMatchResponse {
  IdealMatchResponse({
    required this.topMatch,
    required this.score,
    required this.alternates,
    required this.commonalities,
  });

  final UserModel topMatch;
  final double score;
  final List<IdealMatchAlternate> alternates;
  final List<String> commonalities;

  factory IdealMatchResponse.fromJson(Map<String, dynamic> json) =>
      IdealMatchResponse(
        topMatch: UserModel.fromJson(
          Map<String, dynamic>.from(json['topMatch'] as Map),
        ),
        score: coerceDouble(json['score']) ?? 0.0,
        alternates:
            coerceList(json['alternates'], IdealMatchAlternate.fromJson),
        commonalities: coerceStringList(json['commonalities']),
      );

  Map<String, dynamic> toJson() => {
        'topMatch': topMatch.toJson(),
        'score': score,
        'alternates': alternates.map((a) => a.toJson()).toList(),
        'commonalities': commonalities,
      };
}

/// `SendMessageRequest` — `POST /messages` body.
class SendMessageRequest {
  SendMessageRequest({required this.matchId, required this.text});

  final String matchId;
  final String text;

  Map<String, dynamic> toJson() => {'matchId': matchId, 'text': text};

  factory SendMessageRequest.fromJson(Map<String, dynamic> json) =>
      SendMessageRequest(
        matchId: json['matchId'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );
}
