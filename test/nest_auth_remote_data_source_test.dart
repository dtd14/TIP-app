import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'support/auth_fakes.dart';
import 'support/nest_fixtures.dart';

/// Test fixture follows the direct object returned by the supplied controller.
/// Nested Student fields follow the supplied Prisma schema, not a live response.
Map<String, Object?> meFixture({Object? student, String status = 'ACTIVE'}) => {
  'id': 'account-1',
  'username': 'student',
  'email': 'student@example.com',
  'fullName': 'Nguyễn Văn An',
  'globalRole': 'USER',
  'status': status,
  'schoolUser': null,
  'student': student,
  'companyUser': null,
};
const activeStudent = {
  'id': 'student-1',
  'accountId': 'account-1',
  'status': 'ACTIVE',
};

class ControllerAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? response;
  int status = 200;
  FutureOr<ResponseBody> Function(RequestOptions)? onRequest;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (onRequest != null) return await onRequest!(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Matcher authFailure(FailureKind kind) =>
    isA<AuthFailure>().having((failure) => failure.kind, 'kind', kind);

void main() {
  late MemorySessionStorage storage;
  late AppDependencies dependencies;
  late ControllerAdapter adapter;
  setUp(() {
    storage = MemorySessionStorage();
    dependencies = AppDependencies.create(sessionStorage: storage);
    adapter = ControllerAdapter();
    dependencies.apiClient.dio.httpClientAdapter = adapter;
  });
  tearDown(() async => dependencies.dispose());

  test(
    'default production adapter uses GET me with saved Bearer credential',
    () async {
      storage.value = testCredential;
      adapter.response = meFixture(student: activeStudent);
      final user = await dependencies.authRepository.getCurrentUser();
      expect(user!.canAccessStudentApp, isTrue);
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/auth/me');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer test-only-token',
      );
      expect(adapter.requests.single.data, isNull);
    },
  );

  test(
    'logout uses POST and validated access token, then clears local session',
    () async {
      storage.value = testCredential;
      adapter.response = meFixture(student: activeStudent);
      await dependencies.authRepository.getCurrentUser();
      adapter.response = {'message': 'test-only response ignored'};
      expect(await dependencies.authRepository.logout(), isNull);
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.path, '/auth/logout');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer test-only-token',
      );
      expect(adapter.requests.last.data, isNull);
      expect(storage.value, isNull);
    },
  );

  test('personal Account without Student never gets student access', () async {
    storage.value = testCredential;
    adapter.response = meFixture();
    final user = await dependencies.authRepository.getCurrentUser();
    expect(user!.studentId, isNull);
    expect(user.canAccessStudentApp, isFalse);
  });

  test('inactive account or Student cannot enter student app', () {
    final account = AuthUserModel.fromMeResponse(
      meFixture(student: activeStudent, status: 'SUSPENDED'),
    );
    final student = AuthUserModel.fromMeResponse(
      meFixture(student: {...activeStudent, 'status': 'INACTIVE'}),
    );
    expect(account.canAccessStudentApp, isFalse);
    expect(student.canAccessStudentApp, isFalse);
  });

  test(
    'malformed Student, wrong account linkage and unknown envelope fail safely',
    () {
      for (final response in <Object?>[
        {'data': meFixture(student: activeStudent)},
        meFixture(student: 'student-1'),
        meFixture(student: {'id': 'student-1'}),
        meFixture(
          student: {...activeStudent, 'accountId': 'different-account'},
        ),
        {'id': 'account-1', 'fullName': 'Student'},
      ]) {
        expect(
          () => AuthUserModel.fromMeResponse(response),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  test('global USER role alone does not grant student access', () {
    final user = AuthUserModel.fromMeResponse(meFixture()..remove('student'));
    expect(user.studentAccessGranted, isFalse);
    expect(user.canAccessStudentApp, isFalse);
  });

  test('JWT-protected me 401 invalidates persisted session', () async {
    storage.value = testCredential;
    adapter.status = 401;
    adapter.response = {'message': 'Unauthorized', 'statusCode': 401};
    final expired = dependencies.authRepository.sessionExpired.first;
    await expectLater(
      dependencies.authRepository.getCurrentUser(),
      throwsA(authFailure(FailureKind.sessionExpired)),
    );
    expect(await expired, isNull);
    expect(storage.value, isNull);
    expect(adapter.requests, hasLength(1));
  });

  test(
    'login sends username and password, verifies me then saves token pair',
    () async {
      adapter.onRequest = (options) => body(
        options.path == '/auth/login'
            ? tokenPair
            : meFixture(student: activeStudent),
      );
      final user = await dependencies.authRepository.login(
        identifier: ' student ',
        password: ' password ',
      );
      expect(user.canAccessStudentApp, isTrue);
      expect(adapter.requests.first.method, 'POST');
      expect(adapter.requests.first.path, '/auth/login');
      expect(adapter.requests.first.data, {
        'username': 'student',
        'password': ' password ',
      });
      expect(adapter.requests.first.headers['Authorization'], isNull);
      expect(adapter.requests.first.contentType, Headers.jsonContentType);
      expect(
        adapter.requests.every(
          (request) => !request.headers.keys.any(
            (header) => header.toLowerCase() == 'x-secret',
          ),
        ),
        isTrue,
      );
      expect(adapter.requests.last.path, '/auth/me');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer test-access',
      );
      expect(storage.value!.refreshToken, 'test-refresh');
    },
  );
  test(
    'register sends exact DTO without confirm/hash/role and never issues a local session',
    () async {
      adapter.response = registrationResponse(otpSent: true);
      final outcome = await dependencies.authRepository.register(
        registrationInput,
      );
      expect(adapter.requests.single.path, '/auth/register-user');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, {
        'fullName': 'Nguyễn Văn An',
        'username': 'student',
        'email': 'student@example.com',
        'password': 'test-password',
      });
      expect(outcome.verificationEmail, 'student@example.com');
      expect(outcome.otpSent, isTrue);
      expect(outcome.user, isNull);
      expect(storage.writes, 0);
    },
  );

  test(
    'verify and resend use the public email verification DTO only',
    () async {
      adapter.response = {'message': 'Email verified successfully'};
      await dependencies.authRepository.verifyEmail(
        email: ' student@example.com ',
        otp: '123456',
      );
      await dependencies.authRepository.resendVerificationEmail(
        ' student@example.com ',
      );
      expect(adapter.requests[0].method, 'POST');
      expect(adapter.requests[0].path, '/auth/verify-otp');
      expect(adapter.requests[0].data, {
        'email': 'student@example.com',
        'otp': '123456',
        'purpose': 'email_verification',
      });
      expect(adapter.requests[1].method, 'POST');
      expect(adapter.requests[1].path, '/auth/resend-otp');
      expect(adapter.requests[1].data, {
        'email': 'student@example.com',
        'purpose': 'email_verification',
      });
      expect(
        adapter.requests.every(
          (request) => request.headers['Authorization'] == null,
        ),
        isTrue,
      );
      expect(storage.writes, 0);
    },
  );

  test(
    'account remains registered when verification email could not be sent',
    () async {
      adapter.response = registrationResponse(otpSent: false);
      final outcome = await dependencies.authRepository.register(
        registrationInput,
      );
      expect(outcome.verificationEmail, 'student@example.com');
      expect(outcome.otpSent, isFalse);
      expect(outcome.message, contains('Tài khoản đã được tạo'));
      expect(outcome.user, isNull);
      expect(storage.writes, 0);
    },
  );

  test(
    'resend reports already verified without implying an email was sent',
    () async {
      adapter.response = {'message': 'Email is already verified.'};
      expect(
        await dependencies.authRepository.resendVerificationEmail(
          'student@example.com',
        ),
        VerificationResendOutcome.alreadyVerified,
      );
      expect(adapter.requests.single.path, '/auth/resend-otp');
    },
  );

  test(
    'registration and OTP timeouts are never retried or authenticated',
    () async {
      storage.value = testCredential;
      adapter.response = meFixture(student: activeStudent);
      await dependencies.authRepository.getCurrentUser();
      adapter.requests.clear();
      adapter.onRequest = (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
      final operations = <Future<void> Function()>[
        () async {
          await dependencies.authRepository.register(registrationInput);
        },
        () async {
          await dependencies.authRepository.resendVerificationEmail(
            'student@example.com',
          );
        },
        () => dependencies.authRepository.verifyEmail(
          email: 'student@example.com',
          otp: '123456',
        ),
      ];
      for (final operation in operations) {
        await expectLater(
          operation(),
          throwsA(authFailure(FailureKind.timeout)),
        );
      }
      expect(adapter.requests.map((request) => request.path), [
        '/auth/register-user',
        '/auth/resend-otp',
        '/auth/verify-otp',
      ]);
      expect(
        adapter.requests.every(
          (request) =>
              request.headers['Authorization'] == null &&
              request.contentType == Headers.jsonContentType &&
              !request.headers.keys.any(
                (header) => header.toLowerCase() == 'x-secret',
              ),
        ),
        isTrue,
      );
      expect(storage.value, testCredential);
    },
  );

  test(
    'invalid login token pair never creates a local session or fetches me',
    () async {
      adapter.response = {'accessToken': 'test-access', 'refreshToken': ''};
      await expectLater(
        dependencies.authRepository.login(
          identifier: 'student',
          password: 'test-password',
        ),
        throwsA(authFailure(FailureKind.server)),
      );
      expect(adapter.requests, hasLength(1));
      expect(storage.value, isNull);
    },
  );

  test(
    'profile failure after login revokes issued session without saving it',
    () async {
      adapter.onRequest = (request) => request.path == '/auth/login'
          ? body(tokenPair)
          : request.path == '/auth/me'
          ? body({
              'statusCode': 403,
              'message': 'Account is not active',
            }, status: 403)
          : body({'message': 'Logged out'});
      await expectLater(
        dependencies.authRepository.login(
          identifier: 'student',
          password: 'test-password',
        ),
        throwsA(authFailure(FailureKind.inactiveAccount)),
      );
      expect(adapter.requests.map((request) => request.path), [
        '/auth/login',
        '/auth/me',
        '/auth/logout',
      ]);
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer test-access',
      );
      expect(storage.writes, 0);
    },
  );

  test(
    'Bearer-only endpoints reject saved cookie before sending any request',
    () async {
      storage.value = const SessionCredential(
        kind: CredentialKind.cookie,
        value: 'session=test-only',
      );
      await expectLater(
        dependencies.authRepository.getCurrentUser(),
        throwsA(authFailure(FailureKind.sessionExpired)),
      );
      expect(adapter.requests, isEmpty);
      expect(storage.value, isNull);
    },
  );
}
