import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

enum ConnectivityState { connected, disconnected, checking }

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  Timer? _timer;

  ConnectivityNotifier() : super(ConnectivityState.connected) {
    _startMonitoring();
  }

  void _startMonitoring() {
    // Check immediately
    _checkConnectivity();
    // Then check every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (state != ConnectivityState.connected) {
          state = ConnectivityState.connected;
        }
      } else {
        state = ConnectivityState.disconnected;
      }
    } on SocketException catch (_) {
      state = ConnectivityState.disconnected;
    } on TimeoutException catch (_) {
      state = ConnectivityState.disconnected;
    } catch (_) {
      // Keep current state on unexpected errors
    }
  }

  /// Force a connectivity check now.
  Future<void> checkNow() async {
    state = ConnectivityState.checking;
    await _checkConnectivity();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
