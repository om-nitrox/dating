import 'user_model.dart';

class MatchModel {
  final String id;
  final List<UserModel> users;
  final MessagePreview? lastMessage;
  final int unreadCount;
  final DateTime createdAt;

  MatchModel({
    required this.id,
    required this.users,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['_id'] ?? json['id'] ?? '',
      users: (json['users'] as List?)
              ?.map((u) => UserModel.fromJson(u))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] != null
          ? MessagePreview.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  UserModel otherUser(String myId) {
    return users.firstWhere(
      (u) => u.id != myId,
      orElse: () => users.first,
    );
  }
}

class MessagePreview {
  final String text;
  final String sender;
  final bool seen;
  final DateTime createdAt;

  MessagePreview({
    required this.text,
    required this.sender,
    required this.seen,
    required this.createdAt,
  });

  factory MessagePreview.fromJson(Map<String, dynamic> json) {
    return MessagePreview(
      text: json['text'] ?? '',
      sender: json['sender'] ?? '',
      seen: json['seen'] ?? false,
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
