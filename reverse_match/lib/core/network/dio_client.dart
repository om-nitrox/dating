import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';
import '../storage/secure_storage_service.dart';
import 'api_exceptions.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  final storage = ref.read(secureStorageProvider);

  // Retry interceptor for network errors
  dio.interceptors.add(InterceptorsWrapper(
    onError: (error, handler) async {
      // Retry on connection errors (max 2 retries)
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        final int retries = (error.requestOptions.extra['_retries'] as int?) ?? 0;
        if (retries < 2) {
          error.requestOptions.extra['_retries'] = retries + 1;
          await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
          try {
            final response = await dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } catch (_) {}
        }
      }
      handler.next(error);
    },
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        // Try to refresh token
        final refreshToken = await storage.getRefreshToken();
        if (refreshToken != null) {
          try {
            final refreshDio = Dio(BaseOptions(
              baseUrl: ApiEndpoints.baseUrl,
            ));
            final response = await refreshDio.post(
              ApiEndpoints.refreshToken,
              data: {'refreshToken': refreshToken},
            );

            final newAccess = response.data['accessToken'] as String;
            final newRefresh = response.data['refreshToken'] as String;
            await storage.saveTokens(newAccess, newRefresh);

            // Retry original request
            error.requestOptions.headers['Authorization'] =
                'Bearer $newAccess';
            final retryResponse = await dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (_) {
            await storage.clearTokens();
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: UnauthorizedException('Session expired'),
              ),
            );
          }
        }
      }
      handler.next(error);
    },
  ));

  return dio;
});
