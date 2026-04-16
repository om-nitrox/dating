import '../../../shared/models/user_model.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthOtpSent extends AuthState {
  final String email;
  const AuthOtpSent(this.email);
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  final bool isNewUser;
  const AuthAuthenticated(this.user, {this.isNewUser = false});
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}
