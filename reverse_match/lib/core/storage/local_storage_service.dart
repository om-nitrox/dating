import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';

final sharedPreferencesProvider = Provider<SharedPreferencesAsync>((ref) {
  return SharedPreferencesAsync();
});

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService(ref.read(sharedPreferencesProvider));
});

class LocalStorageService {
  final SharedPreferencesAsync _prefs;

  LocalStorageService(this._prefs);

  Future<bool> hasSeenOnboarding() async =>
      await _prefs.getBool(StorageKeys.onboardingSeen) ?? false;

  Future<void> setOnboardingSeen() =>
      _prefs.setBool(StorageKeys.onboardingSeen, true);

  Future<bool> isProfileComplete() async =>
      await _prefs.getBool(StorageKeys.profileComplete) ?? false;

  Future<void> setProfileComplete(bool value) =>
      _prefs.setBool(StorageKeys.profileComplete, value);
}
