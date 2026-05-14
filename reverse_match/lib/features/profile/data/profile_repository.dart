// Phase 1.8 — repository unification. Consumes ReverseMatchApiClient.
//
// Canonical profile repository. Phase 0.x kept an older copy at
// `features/profile_setup/data/profile_repository.dart` that wrapped raw
// Dio. That file is now a re-export shim pointing here so the dozens of
// existing imports keep compiling.
//
// All methods return the legacy [UserModel] / [PhotoModel] types from
// `lib/shared/models/` so widgets/notifiers don't need updates.

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/_api_adapters.dart';
import '../../../shared/models/user_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.read(apiClientProvider).profile,
    // FCM token endpoint is not yet in the OpenAPI spec — fall back to the
    // shared Dio for that one call. Stays inside `data/` so the rule that
    // forbids raw Dio outside `data/` is upheld.
    ref.read(dioProvider),
  );
});

class ProfileRepository {
  final api.ProfileApi _profile;
  final Dio _dio;

  ProfileRepository(this._profile, this._dio);

  Future<ApiResult<UserModel>> getProfile() async {
    try {
      final user = await _profile.getProfile();
      return Success(user.toLegacy());
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to get profile'));
    }
  }

  /// `payload` is a partial PATCH-style map matching `ProfileUpdateRequest`
  /// in the OpenAPI spec. We pass it straight through to the generated
  /// request builder via `setRaw` so callers can keep using map literals.
  Future<ApiResult<UserModel>> updateProfile(Map<String, dynamic> payload) async {
    try {
      final body = api.ProfileUpdateRequest();
      payload.forEach(body.setRaw);
      final user = await _profile.updateProfile(body);
      return Success(user.toLegacy());
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to update profile'));
    }
  }

  /// Upload one or more photo files. Backend caps at 6 photos total —
  /// validation lives there, not here.
  Future<ApiResult<List<PhotoModel>>> uploadPhotos(List<File> files) async {
    try {
      final parts = <MultipartFile>[];
      for (final file in files) {
        parts.add(await MultipartFile.fromFile(file.path));
      }
      final response = await _profile.uploadPhotos(parts);
      return Success(
        response.photos
            .map((p) => PhotoModel(url: p.url, publicId: p.publicId))
            .toList(),
      );
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to upload photos'));
    }
  }

  Future<ApiResult<void>> deletePhoto(String publicId) async {
    try {
      // The generated client expects the publicId already URL-encoded.
      await _profile.deletePhoto(Uri.encodeComponent(publicId));
      return const Success(null);
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to delete photo'));
    }
  }

  Future<ApiResult<List<PhotoModel>>> reorderPhotos(List<String> publicIds) async {
    try {
      final response = await _profile.reorderPhotos(
        api.PhotoReorderRequest(photoIds: publicIds),
      );
      return Success(
        response.photos
            .map((p) => PhotoModel(url: p.url, publicId: p.publicId))
            .toList(),
      );
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to reorder photos'));
    }
  }

  Future<ApiResult<bool>> uploadSelfie(File file) async {
    try {
      final part = await MultipartFile.fromFile(file.path);
      final response = await _profile.uploadSelfie(part);
      return Success(response.verified);
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to upload selfie'));
    }
  }

  /// Register/refresh the FCM device token. The endpoint is `/profile/fcm-token`
  /// and is NOT yet in `docs/api/openapi.yaml`, so we still go through raw
  /// Dio for now.
  ///
  /// TODO(spec): add `/profile/fcm-token` to the OpenAPI spec and route this
  /// through the generated `ProfileApi`.
  Future<ApiResult<void>> registerFcmToken({
    required String token,
    required String deviceId,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.fcmToken,
        data: {'token': token, 'deviceId': deviceId},
      );
      return const Success(null);
    } on DioException catch (e) {
      return Failure(_toException(e, 'Failed to register FCM token'));
    }
  }

  AppException _toException(DioException e, String fallback) {
    final message = _extractMessage(e) ?? fallback;
    final status = e.response?.statusCode;
    if (status == 401) return UnauthorizedException(message);
    return ServerException(message, status);
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
