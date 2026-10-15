import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthFailure?> get sessionExpired;
  Future<AuthUser> login({
    required String identifier,
    required String password,
  });
  Future<RegistrationOutcome> register(RegistrationInput input);
  Future<AuthUser?> getCurrentUser();

  /// Returns a safe warning when server sign-out failed, after local sign-out.
  Future<String?> logout();
  Future<void> verifyEmail({required String email, required String otp});
  Future<VerificationResendOutcome> resendVerificationEmail(String email);
}
