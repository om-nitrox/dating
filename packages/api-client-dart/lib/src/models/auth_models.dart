// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Auth-related request/response shapes.

import 'user_models.dart';

/// `EmailRequest` — `POST /auth/signup` body.
class EmailRequest {
  EmailRequest({required this.email});

  final String email;

  Map<String, dynamic> toJson() => {'email': email};

  factory EmailRequest.fromJson(Map<String, dynamic> json) =>
      EmailRequest(email: json['email'] as String? ?? '');
}

/// `VerifyOtpRequest` — `POST /auth/verify-otp` body.
class VerifyOtpRequest {
  VerifyOtpRequest({required this.email, required this.code});

  final String email;
  final String code;

  Map<String, dynamic> toJson() => {'email': email, 'code': code};

  factory VerifyOtpRequest.fromJson(Map<String, dynamic> json) =>
      VerifyOtpRequest(
        email: json['email'] as String? ?? '',
        code: json['code'] as String? ?? '',
      );
}

/// `GoogleSignInRequest` — `POST /auth/google` body.
class GoogleSignInRequest {
  GoogleSignInRequest({required this.idToken});

  final String idToken;

  Map<String, dynamic> toJson() => {'idToken': idToken};

  factory GoogleSignInRequest.fromJson(Map<String, dynamic> json) =>
      GoogleSignInRequest(idToken: json['idToken'] as String? ?? '');
}

/// `RefreshTokenRequest` — `POST /auth/refresh-token` body.
class RefreshTokenRequest {
  RefreshTokenRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) =>
      RefreshTokenRequest(refreshToken: json['refreshToken'] as String? ?? '');
}

/// `TokenPair` — `POST /auth/refresh-token` response. Also the base of
/// `AuthSuccessResponse` via allOf.
class TokenPair {
  TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

/// `AuthSuccessResponse` — `allOf: [TokenPair, { user, isNewUser }]`.
class AuthSuccessResponse {
  AuthSuccessResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.isNewUser,
  });

  final String accessToken;
  final String refreshToken;
  final UserModel user;
  final bool isNewUser;

  factory AuthSuccessResponse.fromJson(Map<String, dynamic> json) =>
      AuthSuccessResponse(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        user: UserModel.fromJson(
          Map<String, dynamic>.from(json['user'] as Map),
        ),
        isNewUser: json['isNewUser'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'user': user.toJson(),
        'isNewUser': isNewUser,
      };
}

/// `MessageResponse` — `{ message: string }`. Returned by `/auth/signup`.
class MessageResponse {
  MessageResponse({required this.message});

  final String message;

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      MessageResponse(message: json['message'] as String? ?? '');

  Map<String, dynamic> toJson() => {'message': message};
}

/// `ErrorResponse` — shared shape for all non-2xx responses.
class ErrorResponse {
  ErrorResponse({
    required this.code,
    required this.message,
    this.requestId,
  });

  final String code;
  final String message;
  final String? requestId;

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    final err = json['error'];
    if (err is Map) {
      final m = Map<String, dynamic>.from(err);
      return ErrorResponse(
        code: m['code'] as String? ?? '',
        message: m['message'] as String? ?? '',
        requestId: m['requestId'] as String?,
      );
    }
    // Tolerate flatter error shapes from upstream sources (e.g. proxies).
    return ErrorResponse(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? '',
      requestId: json['requestId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'error': {
          'code': code,
          'message': message,
          if (requestId != null) 'requestId': requestId,
        },
      };
}

