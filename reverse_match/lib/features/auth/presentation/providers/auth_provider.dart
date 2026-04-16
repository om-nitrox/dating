import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(secureStorageProvider),
    ref.read(socketServiceProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final SecureStorageService _storage;
  final SocketService _socketService;

  AuthNotifier(this._repo, this._storage, this._socketService)
      : super(const AuthInitial());

  Future<void> checkAuthStatus() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      state = const AuthUnauthenticated();
      return;
    }

    final userId = await _storage.getUserId();
    final gender = await _storage.getUserGender();

    if (userId != null) {
      await _socketService.connect();
      state = AuthAuthenticated(
        UserModel(id: userId, gender: gender),
      );
    } else {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> sendOtp(String email) async {
    state = const AuthLoading();
    final result = await _repo.sendOtp(email);
    switch (result) {
      case Success():
        state = AuthOtpSent(email);
      case Failure(:final exception):
        state = AuthError(exception.message);
    }
  }

  Future<void> verifyOtp(String email, String code) async {
    state = const AuthLoading();
    final result = await _repo.verifyOtp(email, code);
    switch (result) {
      case Success(:final data):
        await _socketService.connect();
        state = AuthAuthenticated(data.user, isNewUser: data.isNewUser);
      case Failure(:final exception):
        state = AuthError(exception.message);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        state = const AuthUnauthenticated();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        state = const AuthError('Failed to get Google ID token');
        return;
      }

      final result = await _repo.googleSignIn(idToken);
      switch (result) {
        case Success(:final data):
          await _socketService.connect();
          state = AuthAuthenticated(data.user, isNewUser: data.isNewUser);
        case Failure(:final exception):
          state = AuthError(exception.message);
      }
    } catch (e) {
      state = AuthError('Google sign-in failed: $e');
    }
  }

  Future<void> logout() async {
    _socketService.disconnect();
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }
}
