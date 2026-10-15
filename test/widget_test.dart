import 'support/notification_fakes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/app.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';

Finder input(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

Future<void> enterLogin(WidgetTester tester) async {
  await tester.enterText(input('loginIdentifier'), 'student');
  await tester.enterText(input('loginPassword'), 'test-password');
}

Future<void> openRegister(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('openRegister')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('openRegister')));
  await tester.pumpAndSettle();
}

Future<void> enterRegister(WidgetTester tester) async {
  for (final entry in {
    'registerName': 'Nguyễn Văn An',
    'registerUsername': 'student',
    'registerEmail': 'student@example.com',
    'registerPassword': 'test-password',
    'registerConfirm': 'test-password',
  }.entries) {
    await tester.ensureVisible(input(entry.key));
    await tester.enterText(input(entry.key), entry.value);
  }
}

void main() {
  late FakeAuthRemote remote;
  late MemorySessionStorage storage;
  late AppDependencies dependencies;
  setUp(() {
    remote = FakeAuthRemote();
    storage = MemorySessionStorage();
    dependencies = AppDependencies.create(
      notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      notificationsRepository: FakeNotificationsRepository(),
      authRemote: remote,
      sessionStorage: storage,
      dashboardRepository: FakeDashboardRepository(),
    );
  });
  tearDown(() async => dependencies.dispose());
  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();
  }

  testWidgets('login validates empty fields without remote request', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('loginSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
    expect(remote.loginCalls, 0);
  });

  testWidgets('login error preserves input and password visibility works', (
    tester,
  ) async {
    remote.onLogin = (_, _) async => throw const ApiException(
      AuthFailure(
        FailureKind.invalidCredentials,
        'Thông tin đăng nhập không đúng.',
      ),
    );
    await start(tester);
    await enterLogin(tester);
    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('loginPassword')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.obscureText, isFalse);
    await tester.tap(find.byKey(const Key('loginSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin đăng nhập không đúng.'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(input('loginIdentifier')).controller!.text,
      'student',
    );
    expect(
      tester.widget<TextFormField>(input('loginPassword')).controller!.text,
      'test-password',
    );
  });

  testWidgets(
    'login loading disables repeat submits then routes to main and logout',
    (tester) async {
      final pending = Completer<AuthSessionModel>();
      remote.onLogin = (_, _) => pending.future;
      await start(tester);
      await enterLogin(tester);
      await tester.tap(find.byKey(const Key('loginSubmit')));
      await tester.pump();
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('loginSubmit')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('openRegister')))
            .onPressed,
        isNull,
      );
      expect(remote.loginCalls, 1);
      pending.complete(testSession);
      await tester.pumpAndSettle();
      expect(find.text('TIP Career'), findsOneWidget);
      expect(find.byKey(const Key('openRegister')), findsNothing);
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmLogout')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
      expect(storage.value, isNull);
    },
  );

  testWidgets(
    'registered account without session returns to login with server notice',
    (tester) async {
      remote.onRegister = (_) async =>
          const RegistrationModel(message: 'Vui lòng chờ phê duyệt.');
      await start(tester);
      await openRegister(tester);
      await enterRegister(tester);
      await tester.ensureVisible(find.byKey(const Key('registerSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registerSubmit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
      expect(find.text('Vui lòng chờ phê duyệt.'), findsOneWidget);
      expect(find.text('TIP Career'), findsNothing);
      expect(storage.value, isNull);
      expect(remote.lastRegistration!.email, 'student@example.com');
    },
  );

  testWidgets('duplicate email shows field error and retains entered data', (
    tester,
  ) async {
    remote.onRegister = (_) async => throw const ApiException(
      AuthFailure(
        FailureKind.validation,
        'Không thể tạo tài khoản.',
        fieldErrors: {'email': 'Email đã được sử dụng.'},
      ),
    );
    await start(tester);
    await openRegister(tester);
    await enterRegister(tester);
    await tester.ensureVisible(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(input('registerEmail'));
    expect(find.text('Email đã được sử dụng.'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(input('registerName')).controller!.text,
      'Nguyễn Văn An',
    );
    expect(
      tester.widget<TextFormField>(input('registerPassword')).controller!.text,
      'test-password',
    );
  });

  testWidgets(
    'registration verifies email then returns to login without a session',
    (tester) async {
      remote.onRegister = (_) async => const RegistrationModel(
        message: 'Tạo tài khoản thành công. Vui lòng xác minh email.',
        verificationEmail: 'student@example.com',
        otpSent: true,
      );
      await start(tester);
      await openRegister(tester);
      await enterRegister(tester);
      await tester.ensureVisible(find.byKey(const Key('registerSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registerSubmit')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(input('verifyEmail')).controller!.text,
        'student@example.com',
      );
      expect(
        tester.widget<TextButton>(find.byKey(const Key('resendOtp'))).onPressed,
        isNull,
      );
      expect(storage.value, isNull);
      await tester.enterText(input('verifyOtp'), '123456');
      await tester.ensureVisible(find.byKey(const Key('verifySubmit')));
      await tester.tap(find.byKey(const Key('verifySubmit')));
      await tester.pumpAndSettle();
      expect(remote.verifyCalls, 1);
      expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
      expect(find.textContaining('Email đã được xác minh'), findsOneWidget);
      expect(storage.value, isNull);
      expect(remote.loginCalls, 0);
      expect(find.byKey(const Key('registerName')), findsNothing);
    },
  );

  testWidgets('resend acknowledgement shows once in a snackbar', (
    tester,
  ) async {
    await start(tester);
    await tester.ensureVisible(find.byKey(const Key('openVerification')));
    await tester.tap(find.byKey(const Key('openVerification')));
    await tester.pumpAndSettle();
    await tester.enterText(input('verifyEmail'), 'student@example.com');
    await tester.ensureVisible(find.byKey(const Key('resendOtp')));
    await tester.tap(find.byKey(const Key('resendOtp')));
    await tester.pumpAndSettle();
    final message = find.textContaining(
      'Yêu cầu gửi mã xác minh đã được xử lý',
    );
    expect(
      find.descendant(of: find.byType(SnackBar), matching: message),
      findsOneWidget,
    );
    expect(message, findsOneWidget);
    expect(remote.resendCalls, 1);
    expect(
      tester.widget<TextButton>(find.byKey(const Key('resendOtp'))).onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('already verified resend shows login guidance in a snackbar', (
    tester,
  ) async {
    remote.onResendEmail = (_) async =>
        VerificationResendOutcome.alreadyVerified;
    await start(tester);
    await tester.ensureVisible(find.byKey(const Key('openVerification')));
    await tester.tap(find.byKey(const Key('openVerification')));
    await tester.pumpAndSettle();
    await tester.enterText(input('verifyEmail'), 'student@example.com');
    await tester.ensureVisible(find.byKey(const Key('resendOtp')));
    await tester.tap(find.byKey(const Key('resendOtp')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(
          'Email này đã được xác minh. Bạn có thể đăng nhập.',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Yêu cầu gửi mã'), findsNothing);
    expect(
      tester.widget<TextButton>(find.byKey(const Key('resendOtp'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('OTP failure preserves email and code for retry', (tester) async {
    remote.onRegister = (_) async => const RegistrationModel(
      message: 'Tài khoản đã được tạo, hãy gửi lại mã.',
      verificationEmail: 'student@example.com',
    );
    remote.onVerifyEmail = (_, _) async => throw const ApiException(
      AuthFailure(
        FailureKind.validation,
        'Mã xác minh không đúng hoặc đã hết hạn.',
        fieldErrors: {'otp': 'Mã không đúng hoặc đã hết hạn.'},
      ),
    );
    await start(tester);
    await openRegister(tester);
    await enterRegister(tester);
    await tester.ensureVisible(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextButton>(find.byKey(const Key('resendOtp'))).onPressed,
      isNotNull,
    );
    await tester.enterText(input('verifyOtp'), '123456');
    await tester.ensureVisible(find.byKey(const Key('verifySubmit')));
    await tester.tap(find.byKey(const Key('verifySubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Mã không đúng hoặc đã hết hạn.'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(input('verifyOtp')).controller!.text,
      '123456',
    );
    expect(
      tester.widget<TextFormField>(input('verifyEmail')).controller!.text,
      'student@example.com',
    );
    expect(storage.value, isNull);
  });

  testWidgets('confirmation mismatch does not register', (tester) async {
    await start(tester);
    await openRegister(tester);
    await enterRegister(tester);
    await tester.enterText(input('registerConfirm'), 'different');
    await tester.ensureVisible(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    expect(remote.registerCalls, 0);
  });

  testWidgets('ACTIVE account without Student logs in to home and can logout', (
    tester,
  ) async {
    remote.onLogin = (_, _) async => const AuthSessionModel(
      user: nonStudentUser,
      credential: testCredential,
    );
    await start(tester);
    await enterLogin(tester);
    await tester.tap(find.byKey(const Key('loginSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa thể truy cập'), findsNothing);
    expect(find.text('TIP Career'), findsOneWidget);
    expect(find.byKey(const Key('nav0')), findsOneWidget);
    expect(find.byKey(const Key('nav2')), findsNothing);
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmLogout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
    expect(storage.value, isNull);
  });

  testWidgets(
    'stored session is checked against backend adapter before main screen',
    (tester) async {
      storage.value = testCredential;
      await start(tester);
      expect(remote.currentUserCalls, 1);
      expect(find.text('TIP Career'), findsOneWidget);
    },
  );

  testWidgets(
    'small screen and keyboard can scroll through registration without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await start(tester);
      await openRegister(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await enterRegister(tester);
      await tester.ensureVisible(find.byKey(const Key('registerSubmit')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('registerSubmit')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'explicit missing-contract adapter reports unavailable instead of fake success',
    (tester) async {
      final blocked = AppDependencies.create(
        notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
        notificationsRepository: FakeNotificationsRepository(),
        authRemote: const ContractMissingAuthDataSource(),
        sessionStorage: storage,
      );
      addTearDown(blocked.dispose);
      await tester.pumpWidget(MyApp(dependencies: blocked));
      await tester.pumpAndSettle();
      await enterLogin(tester);
      await tester.tap(find.byKey(const Key('loginSubmit')));
      await tester.pumpAndSettle();
      expect(find.text(authIntegrationFailure.message), findsOneWidget);
      expect(find.text('TIP Career'), findsNothing);
      expect(storage.value, isNull);
    },
  );
}
