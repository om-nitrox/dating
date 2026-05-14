// Phase 1.8 — repository unification. Consumes ReverseMatchApiClient.
//
// Thin wrapper around `GET /config`. The settings screen uses this to load
// privacy / terms URLs and the support email.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return ConfigRepository(ref.read(apiClientProvider).config);
});

class ConfigRepository {
  final api.ConfigApi _config;

  ConfigRepository(this._config);

  Future<ApiResult<AppConfigModel>> getConfig() async {
    try {
      final c = await _config.getConfig();
      return Success(
        AppConfigModel(
          termsOfServiceUrl: c.termsOfServiceUrl,
          privacyPolicyUrl: c.privacyPolicyUrl,
          supportEmail: c.supportEmail,
          minAppVersion: c.minAppVersion,
        ),
      );
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to load config'),
      );
    }
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

/// Mirror of the generated `AppConfig` so the UI doesn't import from the
/// generated package. Same fields, same names.
class AppConfigModel {
  final String termsOfServiceUrl;
  final String privacyPolicyUrl;
  final String supportEmail;
  final String minAppVersion;

  const AppConfigModel({
    required this.termsOfServiceUrl,
    required this.privacyPolicyUrl,
    required this.supportEmail,
    required this.minAppVersion,
  });
}
