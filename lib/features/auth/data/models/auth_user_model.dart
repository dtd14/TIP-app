import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

/// Parses the direct object explicitly returned by AuthController.me().
/// Unknown envelopes and malformed Student data must never grant access.
abstract final class AuthUserModel {
  static AuthUser fromMeResponse(Object? response) {
    const invalid = ApiException(
      AuthFailure(
        FailureKind.server,
        'Không thể xác nhận thông tin tài khoản từ máy chủ. Vui lòng thử lại.',
      ),
    );
    if (response is! Map<String, dynamic>) {
      throw invalid;
    }
    final id = response['id'];
    final fullName = response['fullName'];
    final status = response['status'];
    if (id is! String ||
        id.trim().isEmpty ||
        fullName is! String ||
        status is! String ||
        status.isEmpty) {
      throw invalid;
    }
    final student = response['student'];
    String? studentId;
    String? studentStatus;
    if (student != null) {
      if (student is! Map<String, dynamic>) {
        throw invalid;
      }
      final idValue = student['id'];
      final statusValue = student['status'];
      if (idValue is! String ||
          idValue.trim().isEmpty ||
          statusValue is! String ||
          statusValue.isEmpty ||
          (student.containsKey('accountId') && student['accountId'] != id)) {
        throw invalid;
      }
      studentId = idValue;
      studentStatus = statusValue;
    }
    Map<String, dynamic>? organization(String key) {
      final value = response[key];
      if (value == null) return null;
      if (value is! Map<String, dynamic> ||
          (value.containsKey('accountId') && value['accountId'] != id)) {
        throw invalid;
      }
      return value;
    }

    final school = organization('schoolUser');
    final company = organization('companyUser');
    String? optionalString(Object? value) {
      if (value == null) return null;
      if (value is! String) throw invalid;
      return value;
    }

    return AuthUser(
      id: id,
      fullName: fullName,
      accountStatus: status,
      studentId: studentId,
      studentStatus: studentStatus,
      // Membership comes from the JWT-protected me response, never globalRole.
      studentAccessGranted: studentId != null,
      globalRole: optionalString(response['globalRole']) ?? '',
      // JWT-protected /auth/me rejects unverified accounts on the backend.
      emailVerified: true,
      hasSchoolProfile: school != null,
      hasCompanyProfile: company != null,
      schoolRole: optionalString(school?['role']),
      schoolStatus: optionalString(school?['status']),
      email: optionalString(response['email']),
      username: optionalString(response['username']),
    );
  }
}

/// Internal adapter output. Not a guessed JSON shape for the remote API.
class AuthSessionModel {
  const AuthSessionModel({required this.user, required this.credential});
  final AuthUser user;
  final SessionCredential credential;
}

class RegistrationModel {
  const RegistrationModel({
    required this.message,
    this.session,
    this.verificationEmail,
    this.otpSent = false,
  });
  final String message;
  final AuthSessionModel? session;
  final String? verificationEmail;
  final bool otpSent;

  factory RegistrationModel.fromResponse(Object? response) {
    const invalid = ApiException(
      AuthFailure(
        FailureKind.server,
        'Máy chủ trả về kết quả đăng ký không hợp lệ. Vui lòng kiểm tra trước khi thử lại.',
      ),
    );
    if (response is! Map<String, dynamic> ||
        response['otpSent'] is! bool ||
        response['account'] is! Map<String, dynamic> ||
        response['message'] is! String) {
      throw invalid;
    }
    final account = response['account'] as Map<String, dynamic>;
    if (account['id'] is! String ||
        (account['id'] as String).isEmpty ||
        account['email'] is! String) {
      throw invalid;
    }
    final sent = response['otpSent'] as bool;
    return RegistrationModel(
      message: sent
          ? 'Tạo tài khoản thành công. Vui lòng xác minh email trước khi đăng nhập.'
          : 'Tài khoản đã được tạo nhưng chưa gửi được mã. Vui lòng yêu cầu mã ở màn hình xác minh email.',
      verificationEmail: account['email'] as String,
      otpSent: sent,
    );
  }
}

abstract final class AuthTokenPairModel {
  static SessionCredential fromResponse(Object? response) {
    const invalid = ApiException(
      AuthFailure(
        FailureKind.server,
        'Máy chủ chưa cấp cặp token hợp lệ. Vui lòng thử lại.',
      ),
    );
    if (response is! Map<String, dynamic> ||
        response['accessToken'] is! String ||
        response['refreshToken'] is! String) {
      throw invalid;
    }
    final credential = SessionCredential(
      kind: CredentialKind.bearer,
      value: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
    );
    if (!credential.isValid) throw invalid;
    return credential;
  }
}
