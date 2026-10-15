import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';

class VerifyEmail {
  const VerifyEmail(this.repository);
  final AuthRepository repository;
  Future<void> call({required String email, required String otp}) =>
      repository.verifyEmail(email: email, otp: otp);
}

class ResendVerificationEmail {
  const ResendVerificationEmail(this.repository);
  final AuthRepository repository;
  Future<VerificationResendOutcome> call(String email) =>
      repository.resendVerificationEmail(email);
}
