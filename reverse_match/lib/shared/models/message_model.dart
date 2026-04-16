class MessageModel {
  final String id;
  final String matchId;
  final String sender;
  final String text;
  final bool seen;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.matchId,
    required this.sender,
    required this.text,
    this.seen = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'] ?? json['id'] ?? '',
      matchId: json['matchId'] ?? '',
      sender: json['sender'] ?? '',
      text: json['text'] ?? '',
      seen: json['seen'] ?? false,
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
