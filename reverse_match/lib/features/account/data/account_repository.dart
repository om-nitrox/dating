// Phase 1.8 — repository unification. Consumes ReverseMatchApiClient.
//
// `deleteAccount` is wired through the generated client. `exportAccountData`
// is being added by backend Phase 1.17 — the generated client does not yet
// expose it, so we fall back to raw Dio with a clear TODO.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    ref.read(apiClientProvider).account,
    // Temporary: until /account/export ships in the OpenAPI spec, we need
    // direct Dio access. Stays inside `data/`.
    ref.read(dioProvider),
  );
});

class AccountRepository {
  final api.AccountApi _account;
  final Dio _dio;

  AccountRepository(this._account, this._dio);

  /// `confirmation` MUST equal the magic string `DELETE_MY_ACCOUNT` —
  /// enforced backend-side, sent verbatim.
  Future<ApiResult<void>> deleteAccount(String confirmation) async {
    try {
      await _account.deleteAccount(
        api.AccountDeleteRequest(confirmation: confirmation),
      );
      return const Success(null);
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to delete account'),
      );
    }
  }

  /// Backend Phase 1.17 is adding `GET /account/export`. Until the
  /// generated client exposes a typed call for it, we go through raw Dio.
  ///
  /// TODO(phase-1.17): once `AccountApi.exportAccountData` lands, switch
  /// this to `_account.exportAccountData()`.
  Future<ApiResult<Map<String, dynamic>>> exportAccountData() async {
    try {
      final response = await _dio.get<dynamic>('/account/export');
      final data = response.data;
      if (data is Map<String, dynamic>) return Success(data);
      if (data is Map) return Success(Map<String, dynamic>.from(data));
      return Failure(ServerException('Unexpected export shape'));
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to export account data'),
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
