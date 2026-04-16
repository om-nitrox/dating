import 'user_model.dart';

class LikeModel {
  final String id;
  final UserModel fromUser;
  final String status;
  final DateTime createdAt;

  LikeModel({
    required this.id,
    required this.fromUser,
    required this.status,
    required this.createdAt,
  });

  factory LikeModel.fromJson(Map<String, dynamic> json) {
    return LikeModel(
      id: json['_id'] ?? json['id'] ?? '',
      fromUser: UserModel.fromJson(json['fromUser']),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
