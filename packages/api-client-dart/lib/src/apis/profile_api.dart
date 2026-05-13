// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Tag: `profile`. Operations:
//   - GET    /profile                      -> getProfile
//   - PUT    /profile                      -> updateProfile
//   - POST   /profile/photos               -> uploadPhotos        (multipart)
//   - PUT    /profile/photos/reorder       -> reorderPhotos
//   - DELETE /profile/photos/{publicId}    -> deletePhoto
//   - POST   /profile/selfie               -> uploadSelfie        (multipart)

import 'package:dio/dio.dart';

import '../models/misc_models.dart';
import '../models/user_models.dart';
import '_base_api.dart';

final class ProfileApi extends BaseApi {
  ProfileApi(super.dio);

  Future<UserModel> getProfile() async {
    final response = await dio.get<dynamic>('/profile');
    return UserModel.fromJson(BaseApi.asJsonMap(response));
  }

  Future<UserModel> updateProfile(ProfileUpdateRequest body) async {
    final response = await dio.put<dynamic>(
      '/profile',
      data: body.toJson(),
    );
    return UserModel.fromJson(BaseApi.asJsonMap(response));
  }

  /// Upload up to 6 photos as a single multipart request. Each file goes
  /// under the repeated field name `photos`.
  Future<PhotosResponse> uploadPhotos(List<MultipartFile> photos) async {
    final form = FormData();
    for (final file in photos) {
      form.files.add(MapEntry('photos', file));
    }
    final response = await dio.post<dynamic>(
      '/profile/photos',
      data: form,
    );
    return PhotosResponse.fromJson(BaseApi.asJsonMap(response));
  }

  /// Reorder the user's photos by their Cloudinary `publicId`s. First entry
  /// becomes the primary.
  Future<PhotosResponse> reorderPhotos(PhotoReorderRequest body) async {
    final response = await dio.put<dynamic>(
      '/profile/photos/reorder',
      data: body.toJson(),
    );
    return PhotosResponse.fromJson(BaseApi.asJsonMap(response));
  }

  /// Delete a photo by its Cloudinary `publicId`. The caller MUST URL-encode
  /// the publicId (slashes -> `%2F`).
  Future<void> deletePhoto(String publicIdEncoded) async {
    await dio.delete<dynamic>('/profile/photos/$publicIdEncoded');
  }

  Future<SelfieUploadResponse> uploadSelfie(MultipartFile selfie) async {
    final form = FormData();
    form.files.add(MapEntry('selfie', selfie));
    final response = await dio.post<dynamic>(
      '/profile/selfie',
      data: form,
    );
    return SelfieUploadResponse.fromJson(BaseApi.asJsonMap(response));
  }
}
