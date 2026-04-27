import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      _storage.write(key: StorageKeys.accessToken, value: accessToken),
      _storage.write(key: StorageKeys.refreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: StorageKeys.accessToken);

  Future<String?> getRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.refreshToken),
    ]);
  }

  Future<void> saveUserId(String id) =>
      _storage.write(key: StorageKeys.userId, value: id);

  Future<String?> getUserId() => _storage.read(key: StorageKeys.userId);

  Future<void> saveUserGender(String gender) =>
      _storage.write(key: StorageKeys.userGender, value: gender);

  Future<String?> getUserGender() =>
      _storage.read(key: StorageKeys.userGender);

  /// Returns a stable per-install device id, creating one on first call.
  /// Used by the backend to keep one FCM token per device per user.
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: StorageKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final id = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: StorageKeys.deviceId, value: id);
    return id;
  }

  Future<void> clearAll() => _storage.deleteAll();
}
