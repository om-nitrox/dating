import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../verification/data/verification_repository.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(secureStorageProvider),
    ref.read(socketServiceProvider),
    ref.read(localStorageProvider),
    ref.read(verificationRepositoryProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final SecureStorageService _storage;
  final SocketService _socketService;
  final LocalStorageService _localStorage;
  final VerificationRepository _verification;

  AuthNotifier(
    this._repo,
    this._storage,
    this._socketService,
    this._localStorage,
    this._verification,
  ) : super(const AuthInitial());

  /// The login/generated-client user object does NOT carry `role` or
  /// `selfieReviewStatus` (they're outside the OpenAPI schema). Fetch the
  /// full profile so router redirects (admin gate, girl verification gate)
  /// see authoritative values. Falls back to [fallback] when offline.
  Future<UserModel> _hydrate(UserModel fallback) async {
    final res = await _verification.fetchMe();
    return switch (res) {
      Success(:final data) => await _persistRouting(data),
      Failure() => fallback,
    };
  }

  /// Cache the routing-critical fields so an OFFLINE cold start still routes
  /// admins to the queue and keeps approved girls out of the pending screen.
  Future<UserModel> _persistRouting(UserModel user) async {
    await _storage.saveUserRole(user.role);
    if (user.selfieReviewStatus != null) {
      await _storage.saveSelfieReviewStatus(user.selfieReviewStatus!);
    }
    return user;
  }

  Future<void> checkAuthStatus() async {
    // Only the genuine cold-start should run this. The splash screen calls it
    // on a delayed timer; if an auth flow (e.g. AuthOtpSent) has already moved
    // on by then, a late checkAuthStatus() would overwrite it with
    // AuthUnauthenticated and bounce the user back to /welcome. Guarding on
    // AuthInitial makes the call a no-op once any real flow has started.
    if (state is! AuthInitial) return;

    final token = await _storage.getAccessToken();
    if (token == null) {
      state = const AuthUnauthenticated();
      return;
    }

    final userId = await _storage.getUserId();
    final gender = await _storage.getUserGender();
    final role = await _storage.getUserRole();
    final status = await _storage.getSelfieReviewStatus();

    if (userId != null) {
      await _socketService.connect();
      // Hydrate role + selfieReviewStatus from the server so the router can
      // route admins to the queue and unapproved girls to the pending screen.
      // Offline → fall back to the last-known stored routing fields.
      final fallback = UserModel(
        id: userId,
        gender: gender,
        role: role ?? 'user',
        selfieReviewStatus: status,
        // A stored gender means they finished the identity step, so treat the
        // profile as complete offline (keeps an approved girl out of both
        // onboarding and the pending screen). The fresh fetch corrects this.
        isProfileComplete: gender != null,
      );
      final user = await _hydrate(fallback);
      state = AuthAuthenticated(user);
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
        // Existing users may be admins or pending-approval girls — hydrate so
        // the first redirect is correct. New users have no profile yet.
        final user =
            data.isNewUser ? data.user : await _hydrate(data.user);
        state = AuthAuthenticated(user, isNewUser: data.isNewUser);
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
          final user =
              data.isNewUser ? data.user : await _hydrate(data.user);
          state = AuthAuthenticated(user, isNewUser: data.isNewUser);
        case Failure(:final exception):
          state = AuthError(exception.message);
      }
    } catch (e) {
      state = AuthError('Google sign-in failed: $e');
    }
  }

  Future<void> logout() async {
    // CRITICAL: every step is wrapped so the final `state = ...` ALWAYS runs.
    // Previously, an unhandled exception in socket.disconnect or repo.logout
    // could leave the user stuck on /settings with no redirect firing.
    try {
      _socketService.disconnect();
    } catch (_) {}
    try {
      await _repo.logout();
    } catch (_) {}
    // Also reset profile-complete so a re-login (different account) doesn't
    // inherit the previous user's "skip onboarding" flag from local storage.
    try {
      await _localStorage.setProfileComplete(false);
    } catch (_) {}
    state = const AuthUnauthenticated();
  }

  /// Replace the user object in the current authenticated state.
  /// Used after profile completion in onboarding so the router redirect
  /// (which reads `user.gender` / `user.isProfileComplete`) sees fresh values.
  void updateUser(UserModel user) {
    final current = state;
    if (current is AuthAuthenticated) {
      state = AuthAuthenticated(user, isNewUser: current.isNewUser);
    }
  }

  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }
}
