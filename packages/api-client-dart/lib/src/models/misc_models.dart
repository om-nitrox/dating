// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Remaining schemas: UserIdRequest, ReportUserRequest, AccountDeleteRequest,
// AppConfig, PhotosResponse, UndoSkipResponse, AcceptLikeResponse.

import 'enums.dart';
import '_helpers.dart';
import 'user_models.dart';
import 'match_models.dart';

/// `UserIdRequest` — `{ userId }`. Shared by /swipe/like, /swipe/skip, /block.
class UserIdRequest {
  UserIdRequest({required this.userId});
  final String userId;
  Map<String, dynamic> toJson() => {'userId': userId};
  factory UserIdRequest.fromJson(Map<String, dynamic> json) =>
      UserIdRequest(userId: json['userId'] as String? ?? '');
}

/// `ReportUserRequest` — `POST /report` body.
class ReportUserRequest {
  ReportUserRequest({
    required this.userId,
    required this.reason,
    this.details,
  });

  final String userId;
  final ReportReason reason;
  final String? details;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'reason': reason.toJson(),
        if (details != null) 'details': details,
      };

  factory ReportUserRequest.fromJson(Map<String, dynamic> json) =>
      ReportUserRequest(
        userId: json['userId'] as String? ?? '',
        reason: ReportReason.fromJson(json['reason']) ?? ReportReason.other,
        details: json['details'] as String?,
      );
}

/// `AccountDeleteRequest` — `{ confirmation: "DELETE_MY_ACCOUNT" }`.
class AccountDeleteRequest {
  AccountDeleteRequest({this.confirmation = magicValue});

  static const String magicValue = 'DELETE_MY_ACCOUNT';
  final String confirmation;

  Map<String, dynamic> toJson() => {'confirmation': confirmation};

  factory AccountDeleteRequest.fromJson(Map<String, dynamic> json) =>
      AccountDeleteRequest(
        confirmation: json['confirmation'] as String? ?? magicValue,
      );
}

/// `AppConfig` — unauthenticated config response.
class AppConfig {
  AppConfig({
    required this.termsOfServiceUrl,
    required this.privacyPolicyUrl,
    required this.supportEmail,
    required this.minAppVersion,
  });

  final String termsOfServiceUrl;
  final String privacyPolicyUrl;
  final String supportEmail;
  final String minAppVersion;

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        termsOfServiceUrl: json['termsOfServiceUrl'] as String? ?? '',
        privacyPolicyUrl: json['privacyPolicyUrl'] as String? ?? '',
        supportEmail: json['supportEmail'] as String? ?? '',
        minAppVersion: json['minAppVersion'] as String? ?? '0.0.0',
      );

  Map<String, dynamic> toJson() => {
        'termsOfServiceUrl': termsOfServiceUrl,
        'privacyPolicyUrl': privacyPolicyUrl,
        'supportEmail': supportEmail,
        'minAppVersion': minAppVersion,
      };
}

/// `{ photos: Photo[] }` — wrapper used by `POST /profile/photos` and the
/// reorder endpoint. We type it explicitly since both endpoints share the shape.
class PhotosResponse {
  PhotosResponse({required this.photos});

  final List<Photo> photos;

  factory PhotosResponse.fromJson(Map<String, dynamic> json) => PhotosResponse(
        photos: coerceList(json['photos'], Photo.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'photos': photos.map((p) => p.toJson()).toList(),
      };
}

/// `{ undoneUserId }` — `POST /swipe/undo` response.
class UndoSkipResponse {
  UndoSkipResponse({required this.undoneUserId});
  final String undoneUserId;
  factory UndoSkipResponse.fromJson(Map<String, dynamic> json) =>
      UndoSkipResponse(undoneUserId: json['undoneUserId'] as String? ?? '');
  Map<String, dynamic> toJson() => {'undoneUserId': undoneUserId};
}

/// `{ match: MatchModel }` — `POST /queue/accept/{likeId}` response.
class AcceptLikeResponse {
  AcceptLikeResponse({required this.match});
  final MatchModel match;
  factory AcceptLikeResponse.fromJson(Map<String, dynamic> json) =>
      AcceptLikeResponse(
        match: MatchModel.fromJson(
          Map<String, dynamic>.from(json['match'] as Map),
        ),
      );
  Map<String, dynamic> toJson() => {'match': match.toJson()};
}

/// `PhotoReorderRequest` — `PUT /profile/photos/reorder` body.
class PhotoReorderRequest {
  PhotoReorderRequest({required this.photoIds});

  final List<String> photoIds;

  Map<String, dynamic> toJson() => {'photoIds': photoIds};

  factory PhotoReorderRequest.fromJson(Map<String, dynamic> json) =>
      PhotoReorderRequest(photoIds: coerceStringList(json['photoIds']));
}
