import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_endpoints.dart';
import '../storage/secure_storage_service.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref.read(secureStorageProvider));
});

class SocketService {
  final SecureStorageService _storage;
  io.Socket? _socket;

  SocketService(this._storage);

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    final token = await _storage.getAccessToken();
    if (token == null) return;

    _socket = io.io(
      ApiEndpoints.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      // Connected
    });

    _socket!.onDisconnect((_) {
      // Disconnected
    });

    _socket!.onConnectError((err) {
      // Connection error
    });
  }

  void joinRoom(String roomId) {
    _socket?.emit('join-room', roomId);
  }

  void leaveRoom(String roomId) {
    _socket?.emit('leave-room', roomId);
  }

  void sendMessage(String matchId, String text) {
    _socket?.emit('send-message', {'matchId': matchId, 'text': text});
  }

  void startTyping(String matchId) {
    _socket?.emit('typing-start', matchId);
  }

  void stopTyping(String matchId) {
    _socket?.emit('typing-stop', matchId);
  }

  void markSeen(String matchId) {
    _socket?.emit('mark-seen', {'matchId': matchId});
  }

  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
