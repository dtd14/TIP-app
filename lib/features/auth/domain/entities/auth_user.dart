/// Normalized domain data supplied by a VERIFIED API adapter.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.accountStatus,
    required this.studentAccessGranted,
    this.studentId,
    this.studentStatus,
    this.globalRole = '',
    this.emailVerified = false,
    this.hasSchoolProfile = false,
    this.hasCompanyProfile = false,
    this.schoolRole,
    this.schoolStatus,
    this.email,
    this.username,
  });
  final String id;
  final String fullName;
  final String accountStatus;
  final String? studentId;
  final String? studentStatus;
  final bool studentAccessGranted;
  final String globalRole;
  final bool emailVerified, hasSchoolProfile, hasCompanyProfile;
  final String? schoolRole, schoolStatus, email, username;

  bool get canRequestStudentEnrollment =>
      accountStatus == 'ACTIVE' &&
      emailVerified &&
      globalRole == 'USER' &&
      studentId == null &&
      !hasSchoolProfile &&
      !hasCompanyProfile;

  bool get canViewStudentEnrollments =>
      accountStatus == 'ACTIVE' &&
      emailVerified &&
      globalRole == 'USER' &&
      !hasSchoolProfile &&
      !hasCompanyProfile;

  bool get canReviewStudentEnrollments =>
      accountStatus == 'ACTIVE' &&
      emailVerified &&
      hasSchoolProfile &&
      schoolRole == 'UNIVERSITY_ADMIN' &&
      schoolStatus == 'ACTIVE';

  /// Home access follows the account; Student permissions are checked separately.
  bool get canAccessHome => accountStatus == 'ACTIVE';

  bool get canAccessStudentApp =>
      accountStatus == 'ACTIVE' &&
      studentId != null &&
      studentId!.isNotEmpty &&
      studentStatus == 'ACTIVE' &&
      studentAccessGranted;

  String get accessMessage {
    if (accountStatus == 'PENDING') {
      return 'Tài khoản đang chờ xác minh hoặc phê duyệt.';
    }
    if (accountStatus != 'ACTIVE') {
      return 'Tài khoản hiện không hoạt động hoặc đã bị tạm khóa.';
    }
    if (studentId == null || studentId!.isEmpty) {
      return 'Tài khoản chưa có hồ sơ sinh viên. Vui lòng liên hệ nhà trường.';
    }
    if (studentStatus != 'ACTIVE') {
      return 'Hồ sơ sinh viên hiện không hoạt động.';
    }
    return 'Tài khoản chưa được cấp quyền truy cập ứng dụng sinh viên.';
  }
}

class RegistrationInput {
  const RegistrationInput({
    required this.fullName,
    required this.username,
    required this.email,
    required this.password,
    this.phone,
  });
  final String fullName;
  final String username;
  final String email;
  final String password;
  final String? phone;
  @override
  String toString() => 'RegistrationInput(redacted)';
}

/// An acknowledgement does not confirm that an email reached the inbox.
enum VerificationResendOutcome { accepted, alreadyVerified }

class RegistrationOutcome {
  const RegistrationOutcome({
    required this.message,
    this.user,
    this.verificationEmail,
    this.otpSent = false,
  });
  final String message;

  /// Present only if the server really issued a session.
  final AuthUser? user;
  final String? verificationEmail;
  final bool otpSent;
}
