import 'package:dio/dio.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/network/api_client.dart';
import 'package:tip_app/core/network/api_endpoints.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';
import 'package:tip_app/features/auth/data/datasources/auth_api_error_mapper.dart';
import 'package:tip_app/features/auth/data/datasources/auth_remote_data_source.dart';

class NestAuthRemoteDataSource implements AuthRemoteDataSource {
  NestAuthRemoteDataSource(this.client);
  final ApiClient client;
  Options get _authenticated =>
      Options(extra: {'requiresAuth': true, 'requiresBearerAuth': true});

  Future<T> _request<T>(
    AuthOperation operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw AuthApiErrorMapper.map(error, operation);
    }
  }

  @override
  Future<AuthSessionModel> login({
    required String identifier,
    required String password,
  }) => _request(AuthOperation.login, () async {
    final response = await client.dio.post<Object?>(
      ApiEndpoints.login,
      data: {'username': identifier.trim(), 'password': password},
    );
    final credential = AuthTokenPairModel.fromResponse(response.data);
    try {
      // The login response contains tokens only. Verify the account through me.
      // Explicit new token avoids attaching a previously stored session.
      final me = await _request(
        AuthOperation.profile,
        () => client.dio.get<Object?>(
          ApiEndpoints.currentUser,
          options: Options(
            headers: {'Authorization': 'Bearer ${credential.value}'},
          ),
        ),
      );
      return AuthSessionModel(
        user: AuthUserModel.fromMeResponse(me.data),
        credential: credential,
      );
    } on Object {
      // Best effort cleanup of the server session if profile validation fails.
      try {
        await client.dio.post<Object?>(
          ApiEndpoints.logout,
          options: Options(
            headers: {'Authorization': 'Bearer ${credential.value}'},
          ),
        );
      } on Object {
        /* No credential or raw error is logged. */
      }
      rethrow;
    }
  });

  @override
  Future<RegistrationModel> register(RegistrationInput input) =>
      _request(AuthOperation.register, () async {
        final response = await client.dio.post<Object?>(
          ApiEndpoints.registerPersonalAccount,
          data: {
            'fullName': input.fullName.trim(),
            'username': input.username.trim(),
            'email': input.email.trim(),
            'password': input.password,
            if (input.phone != null && input.phone!.trim().isNotEmpty)
              'phone': input.phone!.trim(),
          },
        );
        return RegistrationModel.fromResponse(response.data);
      });

  @override
  Future<AuthUser> currentUser() => _request(AuthOperation.profile, () async {
    final response = await client.dio.get<Object?>(
      ApiEndpoints.currentUser,
      options: _authenticated,
    );
    return AuthUserModel.fromMeResponse(response.data);
  });

  @override
  Future<SessionCredential> refreshCredential(SessionCredential credential) =>
      _request(AuthOperation.refresh, () async {
        final token = credential.refreshToken;
        if (token == null) throw const ApiException(authIntegrationFailure);
        final response = await client.dio.post<Object?>(
          ApiEndpoints.refreshToken,
          data: {'refreshToken': token},
        );
        return AuthTokenPairModel.fromResponse(response.data);
      });

  @override
  Future<void> logout() => _request(AuthOperation.logout, () async {
    await client.dio.post<Object?>(
      ApiEndpoints.logout,
      options: _authenticated,
    );
  });

  @override
  Future<void> verifyEmail({required String email, required String otp}) =>
      _request(AuthOperation.verifyEmail, () async {
        await client.dio.post<Object?>(
          ApiEndpoints.verifyOtp,
          data: {
            'email': email.trim(),
            'otp': otp,
            'purpose': 'email_verification',
          },
        );
      });

  @override
  Future<VerificationResendOutcome> resendVerificationEmail(String email) =>
      _request(AuthOperation.resendEmail, () async {
        final response = await client.dio.post<Object?>(
          ApiEndpoints.resendOtp,
          data: {'email': email.trim(), 'purpose': 'email_verification'},
        );
        final data = response.data;
        if (data is! Map<String, dynamic> || data['message'] is! String) {
          throw const ApiException(authIntegrationFailure);
        }
        return data['message'] == 'Email is already verified.'
            ? VerificationResendOutcome.alreadyVerified
            : VerificationResendOutcome.accepted;
      });
}
