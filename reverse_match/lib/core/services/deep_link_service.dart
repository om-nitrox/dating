import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService();
});

/// Listens for `reversematch://...` URLs (Stripe Checkout return + share
/// links) and routes them into GoRouter via the root navigator key.
///
/// Initial-link (cold start with a URL) is handled by polling
/// [AppLinks.getInitialAppLink] once at startup. Subsequent links are picked
/// up off [AppLinks.uriLinkStream].
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Begin listening. Idempotent — calling twice is a no-op.
  Future<void> start() async {
    if (_sub != null) return;
    try {
      final initial = await _appLinks.getInitialAppLink();
      if (initial != null) _dispatch(initial);
      _sub = _appLinks.uriLinkStream.listen(
        _dispatch,
        onError: (Object e) =>
            debugPrint('DeepLinkService stream error: $e'),
      );
    } catch (e) {
      debugPrint('DeepLinkService init failed: $e');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _dispatch(Uri uri) {
    if (uri.scheme != 'reversematch') return;

    void run() {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      final router = GoRouter.of(ctx);

      // Boost return URLs from Stripe Checkout: reversematch://boost/success
      // and reversematch://boost/cancel.
      if (uri.host == 'boost') {
        if (uri.path == '/success' || uri.path == '/success/') {
          router.go('/boost/success');
        } else if (uri.path == '/cancel' || uri.path == '/cancel/') {
          router.go('/boost/cancel');
        }
      }
    }

    if (rootNavigatorKey.currentContext != null) {
      run();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    }
  }
}
