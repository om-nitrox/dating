import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../shared/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(dioProvider),
    ref.read(secureStorageProvider),
  );
});

class AuthRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  AuthRepository(this._dio, this._storage);

  Future<ApiResult<String>> sendOtp(String email) async {
    try {
      await _dio.post(ApiEndpoints.signup, data: {'email': email});
      return const Success('OTP sent successfully');
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to send OTP',
        e.response?.statusCode,
      ));
    }
  }

  Future<ApiResult<AuthResult>> verifyOtp(String email, String code) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.verifyOtp,
        data: {'email': email, 'code': code},
      );
      final result = AuthResult.fromJson(response.data);
      await _saveAuth(result);
      return Success(result);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Invalid OTP',
        e.response?.statusCode,
      ));
    }
  }

  Future<ApiResult<AuthResult>> googleSignIn(String idToken) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.googleAuth,
        data: {'idToken': idToken},
      );
      final result = AuthResult.fromJson(response.data);
      await _saveAuth(result);
      return Success(result);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Google sign-in failed',
        e.response?.statusCode,
      ));
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
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

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      user: UserModel.fromJson(json['user']),
      isNewUser: json['isNewUser'] ?? false,
    );
  }
}
