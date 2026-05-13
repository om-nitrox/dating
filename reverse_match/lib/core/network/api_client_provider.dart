// Riverpod provider for the generated REST client.
//
// Centralizes the `ReverseMatchApiClient` instance so every repository that
// migrates to the generated client (Phase 0.2 → 1.8) reads from the same
// place. The client wraps the project-wide Dio (provided by `dioProvider`),
// so all interceptors — auth refresh, dummy mocking, retry — apply to
// generated API calls transparently.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart';

import 'dio_client.dart';

final apiClientProvider = Provider<ReverseMatchApiClient>((ref) {
  return ReverseMatchApiClient(dio: ref.read(dioProvider));
});
