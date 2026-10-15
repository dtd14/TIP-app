import 'dart:async';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'package:tip_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

const studentUser = AuthUser(
  id: 'account-1',
  fullName: 'Nguyễn Văn An',
  accountStatus: 'ACTIVE',
  studentId: 'student-1',
  studentStatus: 'ACTIVE',
  studentAccessGranted: true,
  globalRole: 'USER',
  emailVerified: true,
);
const nonStudentUser = AuthUser(
  id: 'account-2',
  fullName: 'Người dùng',
  accountStatus: 'ACTIVE',
  studentAccessGranted: false,
  globalRole: 'USER',
  emailVerified: true,
);
const testCredential = SessionCredential(
  kind: CredentialKind.bearer,
  value: 'test-only-token',
);
const testSession = AuthSessionModel(
  user: studentUser,
  credential: testCredential,
);
const registrationInput = RegistrationInput(
  fullName: 'Nguyễn Văn An',
  username: 'student',
  email: 'student@example.com',
  password: 'test-password',
);

class MemorySessionStorage implements SessionStorage {
  SessionCredential? value;
  Object? readError;
  Object? writeError;
  Object? clearError;
  Completer<SessionCredential?>? pendingRead;
  int writes = 0;
  int clears = 0;
  @override
  Future<SessionCredential?> read() async {
    if (readError != null) throw readError!;
    if (pendingRead != null) return pendingRead!.future;
    return value;
  }

  @override
  Future<void> write(SessionCredential credential) async {
    if (writeError != null) throw writeError!;
    writes++;
    value = credential;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (clearError != null) throw clearError!;
    value = null;
  }
}

/// Test-only normalized adapter. No actual backend contract is implied.
class FakeAuthRemote implements AuthRemoteDataSource {
  Future<AuthSessionModel> Function(String identifier, String password)?
  onLogin;
  Future<RegistrationModel> Function(RegistrationInput input)? onRegister;
  Future<AuthUser> Function()? onCurrentUser;
  Future<void> Function()? onLogout;
  Future<SessionCredential> Function(SessionCredential)? onRefresh;
  Future<void> Function(String email, String otp)? onVerifyEmail;
  Future<VerificationResendOutcome> Function(String email)? onResendEmail;
  int refreshCalls = 0;
  int verifyCalls = 0;
  int resendCalls = 0;
  int loginCalls = 0;
  int registerCalls = 0;
  int currentUserCalls = 0;
  int logoutCalls = 0;
  String? lastIdentifier;
  String? lastPassword;
  RegistrationInput? lastRegistration;
  @override
  Future<AuthSessionModel> login({
    required String identifier,
    required String password,
  }) async {
    loginCalls++;
    lastIdentifier = identifier;
    lastPassword = password;
    return onLogin == null ? testSession : onLogin!(identifier, password);
  }

  @override
  Future<RegistrationModel> register(RegistrationInput input) async {
    registerCalls++;
    lastRegistration = input;
    return onRegister == null
        ? const RegistrationModel(
            message: 'Đăng ký thành công. Vui lòng đăng nhập.',
          )
        : onRegister!(input);
  }

  @override
  Future<AuthUser> currentUser() async {
    currentUserCalls++;
    return onCurrentUser == null ? studentUser : onCurrentUser!();
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    await onLogout?.call();
  }

  @override
  Future<SessionCredential> refreshCredential(
    SessionCredential credential,
  ) async {
    refreshCalls++;
    return onRefresh == null ? testCredential : onRefresh!(credential);
  }

  @override
  Future<void> verifyEmail({required String email, required String otp}) async {
    verifyCalls++;
    await onVerifyEmail?.call(email, otp);
  }

  @override
  Future<VerificationResendOutcome> resendVerificationEmail(
    String email,
  ) async {
    resendCalls++;
    return onResendEmail == null
        ? VerificationResendOutcome.accepted
        : await onResendEmail!(email);
  }
}
