import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthSessionModel> login({
    required String identifier,
    required String password,
  });
  Future<RegistrationModel> register(RegistrationInput input);
  Future<AuthUser> currentUser();
  Future<void> logout();
  Future<SessionCredential> refreshCredential(SessionCredential credential);
  Future<void> verifyEmail({required String email, required String otp});
  Future<VerificationResendOutcome> resendVerificationEmail(String email);
}

/// Blocks only operations whose request/response contracts are still missing.
/// Performs NO speculative request and never fabricates a successful session.
class ContractMissingAuthDataSource implements AuthRemoteDataSource {
  const ContractMissingAuthDataSource();
  @override
  Future<AuthSessionModel> login({
    required String identifier,
    required String password,
  }) async => throw const ApiException(authIntegrationFailure);
  @override
  Future<RegistrationModel> register(RegistrationInput input) async =>
      throw const ApiException(authIntegrationFailure);
  @override
  Future<AuthUser> currentUser() async =>
      throw const ApiException(authIntegrationFailure);
  @override
  Future<void> logout() async =>
      throw const ApiException(authIntegrationFailure);
  @override
  Future<SessionCredential> refreshCredential(
    SessionCredential credential,
  ) async => throw const ApiException(authIntegrationFailure);
  @override
  Future<void> verifyEmail({
    required String email,
    required String otp,
  }) async => throw const ApiException(authIntegrationFailure);
  @override
  Future<VerificationResendOutcome> resendVerificationEmail(
    String email,
  ) async => throw const ApiException(authIntegrationFailure);
}
