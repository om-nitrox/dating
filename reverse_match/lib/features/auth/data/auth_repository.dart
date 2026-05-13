// MIGRATED: Phase 0.2 — uses generated reverse_match_api client.
//
// Public signatures (`sendOtp`, `verifyOtp`, `googleSignIn`, `logout`) are
// unchanged so all upstream callers (auth_provider, login_screen, otp_screen)
// continue to compile. We swapped the underlying call site from hand-rolled
// `dio.post(...)` to typed `AuthApi` operations, but the auth refresh
// interceptor still lives on Dio and the on-the-wire shape is identical.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../shared/models/_api_adapters.dart';
import '../../../shared/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
    ref.read(secureStorageProvider),
  );
});

class AuthRepository {
  final api.ReverseMatchApiClient _api;
  final SecureStorageService _storage;

  AuthRepository(this._api, this._storage);

  Future<ApiResult<String>> sendOtp(String email) async {
    try {
      final response =
          await _api.auth.requestEmailOtp(api.EmailRequest(email: email));
      return Success(response.message.isEmpty ? 'OTP sent successfully' : response.message);
    } on DioException catch (e) {
      return Failure(ServerException(
        _extractMessage(e) ?? 'Failed to send OTP',
        e.response?.statusCode,
      ));
    }
  }

  Future<ApiResult<AuthResult>> verifyOtp(String email, String code) async {
    try {
      final response = await _api.auth.verifyEmailOtp(
        api.VerifyOtpRequest(email: email, code: code),
      );
      final result = AuthResult._fromApi(response);
      await _saveAuth(result);
      return Success(result);
    } on DioException catch (e) {
      return Failure(ServerException(
        _extractMessage(e) ?? 'Invalid OTP',
        e.response?.statusCode,
      ));
    }
  }

  Future<ApiResult<AuthResult>> googleSignIn(String idToken) async {
    try {
      final response = await _api.auth.googleSignIn(
        api.GoogleSignInRequest(idToken: idToken),
      );
      final result = AuthResult._fromApi(response);
      await _saveAuth(result);
      return Success(result);
    } on DioException catch (e) {
      return Failure(ServerException(
        _extractMessage(e) ?? 'Google sign-in failed',
        e.response?.statusCode,
      ));
    }
  }

  Future<void> logout() async {
    try {
      await _api.auth.logout();
    } catch (_) {}
    await _storage.clearAll();
  }

  Future<void> _saveAuth(AuthResult result) async {
    await _storage.saveTokens(result.accessToken, result.refreshToken);
    await _storage.saveUserId(result.user.id);
    if (result.user.gender != null) {
      await _storage.saveUserGender(result.user.gender!);
    }
  }

  /// Pulls the `error.message` field out of an `ErrorResponse`-shaped
  /// Dio failure body. The shape is documented in `docs/api/openapi.yaml`.
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

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final UserModel user;
  final bool isNewUser;

  AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.isNewUser,
  });

  /// Adapt a generated `AuthSuccessResponse` to the legacy `AuthResult` so
  /// existing callers (`auth_provider`, OTP/login screens) don't change.
  factory AuthResult._fromApi(api.AuthSuccessResponse response) {
    return AuthResult(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      user: response.user.toLegacy(),
      isNewUser: response.isNewUser,
    );
  }

  /// Kept for backwards compatibility with any caller that still hand-rolls
  /// JSON parsing (e.g. when restoring auth state from local storage).
  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      user: UserModel.fromJson(json['user']),
      isNewUser: json['isNewUser'] ?? false,
    );
  }
}
