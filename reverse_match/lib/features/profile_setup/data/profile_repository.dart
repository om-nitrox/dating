import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/user_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(dioProvider));
});

class ProfileRepository {
  final Dio _dio;

  ProfileRepository(this._dio);

  Future<ApiResult<UserModel>> getProfile() async {
    try {
      final response = await _dio.get(ApiEndpoints.profile);
      return Success(UserModel.fromJson(response.data));
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to get profile',
      ));
    }
  }

  Future<ApiResult<UserModel>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(ApiEndpoints.profile, data: data);
      return Success(UserModel.fromJson(response.data));
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to update profile',
      ));
    }
  }

  Future<ApiResult<List<PhotoModel>>> uploadPhotos(List<File> files) async {
    try {
      final formData = FormData();
      for (final file in files) {
        formData.files.add(MapEntry(
          'photos',
          await MultipartFile.fromFile(file.path),
        ));
      }
      final response = await _dio.post(
        ApiEndpoints.uploadPhotos,
        data: formData,
      );
      final photos = (response.data['photos'] as List)
          .map((p) => PhotoModel.fromJson(p))
          .toList();
      return Success(photos);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to upload photos',
      ));
    }
  }

  Future<ApiResult<void>> deletePhoto(String publicId) async {
    try {
      await _dio.delete(ApiEndpoints.deletePhoto(publicId));
      return const Success(null);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to delete photo',
      ));
    }
  }

  Future<ApiResult<List<PhotoModel>>> reorderPhotos(List<String> photoIds) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.reorderPhotos,
        data: {'photoIds': photoIds},
      );
      final photos = (response.data['photos'] as List)
          .map((p) => PhotoModel.fromJson(p))
          .toList();
      return Success(photos);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to reorder photos',
      ));
    }
  }

  Future<ApiResult<bool>> uploadSelfie(File file) async {
    try {
      final formData = FormData.fromMap({
        'selfie': await MultipartFile.fromFile(file.path),
      });
      await _dio.post(ApiEndpoints.uploadSelfie, data: formData);
      return const Success(true);
    } on DioException catch (e) {
      return Failure(ServerException(
        e.response?.data?['error']?['message'] ?? 'Failed to upload selfie',
      ));
    }
  }
}
