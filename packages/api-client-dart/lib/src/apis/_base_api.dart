// Base class for all tag-scoped API wrappers. Holds the Dio instance and
// exposes thin helpers that convert decoded JSON into typed models.

import 'package:dio/dio.dart';

abstract base class BaseApi {
  BaseApi(this.dio);

  final Dio dio;

  /// Returns the JSON body as a [Map] (always — even if the server returned
  /// a different shape we coerce so callers can rely on the contract).
  static Map<String, dynamic> asJsonMap(Response<dynamic> response) {
    final body = response.data;
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: 'Expected JSON object, got ${body.runtimeType}',
    );
  }
}
