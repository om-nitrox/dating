// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `auth`. Operations:
//   - POST /auth/signup        -> requestEmailOtp
//   - POST /auth/verify-otp    -> verifyEmailOtp
//   - POST /auth/google        -> googleSignIn
//   - POST /auth/refresh-token -> refreshTokens
//   - POST /auth/logout        -> logout

import 'package:dio/dio.dart';

import '../models/auth_models.dart';
import '_base_api.dart';

final class AuthApi extends BaseApi {
  AuthApi(super.dio);

  /// `POST /auth/signup` — send a 6-digit OTP to the supplied email.
  Future<MessageResponse> requestEmailOtp(EmailRequest body) async {
    final response = await dio.post<dynamic>(
      '/auth/signup',
      data: body.toJson(),
    );
    return MessageResponse.fromJson(BaseApi.asJsonMap(response));
  }

  /// `POST /auth/verify-otp` — exchange the OTP for tokens + user.
  Future<AuthSuccessResponse> verifyEmailOtp(VerifyOtpRequest body) async {
    final response = await dio.post<dynamic>(
      '/auth/verify-otp',
      data: body.toJson(),
    );
    return AuthSuccessResponse.fromJson(BaseApi.asJsonMap(response));
  }

  /// `POST /auth/google` — Google ID token sign-in.
  Future<AuthSuccessResponse> googleSignIn(GoogleSignInRequest body) async {
    final response = await dio.post<dynamic>(
      '/auth/google',
      data: body.toJson(),
    );
    return AuthSuccessResponse.fromJson(BaseApi.asJsonMap(response));
  }

  /// `POST /auth/refresh-token` — rotate access + refresh tokens.
  Future<TokenPair> refreshTokens(RefreshTokenRequest body) async {
    final response = await dio.post<dynamic>(
      '/auth/refresh-token',
      data: body.toJson(),
    );
    return TokenPair.fromJson(BaseApi.asJsonMap(response));
  }

  /// `POST /auth/logout` — invalidate the current refresh token server-side.
  Future<void> logout() async {
    await dio.post<dynamic>('/auth/logout');
  }
}
