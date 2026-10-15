import 'support/notification_fakes.dart';
import 'package:tip_app/features/profile/data/models/student_profile_model.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/app.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/profile/presentation/pages/student_cv_page.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';
import 'support/enrollment_fakes.dart';

void main() {
  late FakeAuthRemote remote;
  late FakeDashboardRepository dashboard;
  late FakeStudentProfileRepository profileRepo;
  late AppDependencies dependencies;
  setUp(() {
    remote = FakeAuthRemote();
    dashboard = FakeDashboardRepository();
    profileRepo = FakeStudentProfileRepository()
      ..onProfile = dashboard.getStudentProfile;
    dependencies = AppDependencies.create(
      notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      notificationsRepository: FakeNotificationsRepository(),
      authRemote: remote,
      sessionStorage: MemorySessionStorage()..value = testCredential,
      dashboardRepository: dashboard,
      opportunityRepository: dashboard,
      applicationRepository: dashboard,
      internshipRepository: dashboard,
      studentProfileRepository: profileRepo,
    );
  });
  tearDown(() => dependencies.dispose());
  Future<void> start(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('profilePreview'),
        child: MyApp(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav4')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> cv(
    WidgetTester tester, {
    Future<CvUpload?> Function()? picker,
  }) async {
    if (picker == null) {
      await tap(tester, find.byKey(const Key('manageStudentCv')));
    } else {
      final context = tester.element(find.text('Hồ sơ sinh viên'));
      unawaited(
        Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => StudentCvPage(
              user: studentUser,
              repository: dashboard,
              profileRepository: profileRepo,
              onRestricted: (_) {},
              pickCv: picker,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
  }

  CvUpload pdf() => CvUpload(
    name: 'new_cv.pdf',
    bytes: Uint8List.fromList('%PDF-1.7\nfixture'.codeUnits),
  );
  AuthUser namedUser(String name) => AuthUser(
    id: studentUser.id,
    fullName: name,
    accountStatus: studentUser.accountStatus,
    studentId: studentUser.studentId,
    studentStatus: studentUser.studentStatus,
    studentAccessGranted: studentUser.studentAccessGranted,
    globalRole: studentUser.globalRole,
    emailVerified: studentUser.emailVerified,
    email: studentUser.email,
    username: studentUser.username,
    hasSchoolProfile: studentUser.hasSchoolProfile,
    hasCompanyProfile: studentUser.hasCompanyProfile,
    schoolRole: studentUser.schoolRole,
    schoolStatus: studentUser.schoolStatus,
  );

  testWidgets(
    'profile loads independently of the dashboard and omits unsupported fields',
    (tester) async {
      dashboard.onSummary = (_) async => throw const AuthFailure(
        FailureKind.network,
        'Chưa tải được trang chủ.',
      );
      await start(tester);
      expect(find.text('Thông tin học vụ'), findsOneWidget);
      expect(find.text('Công nghệ thông tin'), findsNWidgets(2));
      expect(find.text('Đại học TIP'), findsOneWidget);
      expect(find.text('CV dùng ứng tuyển'), findsOneWidget);
      expect(find.text('Giới tính'), findsNothing);
      expect(find.text('Ngày sinh'), findsNothing);
      expect(find.textContaining('V2.4'), findsNothing);
      expect(dashboard.profileCalls, 1);
    },
  );

  testWidgets(
    'profile opens dedicated CV page, shows absence and returns to profile',
    (tester) async {
      await start(tester);
      await cv(tester);
      expect(find.byType(StudentCvPage), findsOneWidget);
      expect(find.text('Bạn chưa có CV trong hồ sơ.'), findsOneWidget);
      final view = find.descendant(
        of: find.byKey(const Key('viewStudentCv')),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.widget<OutlinedButton>(view).onPressed, isNull);
      await tester.tap(find.byKey(const Key('studentCvBack')));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ sinh viên'), findsOneWidget);
    },
  );

  testWidgets(
    'CV upload sends only the selected PDF and reloads the server link',
    (tester) async {
      String? url;
      dashboard.onProfile = (_) async =>
          StudentProfileModel.profile({...profileFixture(), 'cvUrl': url});
      profileRepo.onUpdate = () async => url = 'https://example.com/new_cv.pdf';
      await start(tester);
      await cv(tester, picker: () async => pdf());
      await tap(tester, find.byKey(const Key('uploadStudentCv')));
      expect(profileRepo.calls, 1);
      expect(profileRepo.name, isNull);
      expect(profileRepo.phone, isNull);
      expect(profileRepo.cv!.name, 'new_cv.pdf');
      expect(find.text('Có CV trong hồ sơ'), findsOneWidget);
      expect(find.text('Đã cập nhật CV trong hồ sơ.'), findsOneWidget);
      expect(
        dashboard.profileCalls,
        3,
      ); // Profile, CV page and acknowledged upload reload.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ sinh viên'), findsOneWidget);
    },
  );

  testWidgets('canceling file selection never sends an update', (tester) async {
    await start(tester);
    await cv(tester, picker: () async => null);
    await tap(tester, find.byKey(const Key('uploadStudentCv')));
    expect(profileRepo.calls, 0);
    expect(find.text('Bạn chưa có CV trong hồ sơ.'), findsOneWidget);
  });

  testWidgets('invalid PDF is rejected before upload', (tester) async {
    await start(tester);
    await cv(
      tester,
      picker: () async => CvUpload(
        name: 'fake.pdf',
        bytes: Uint8List.fromList('not a PDF'.codeUnits),
      ),
    );
    await tap(tester, find.byKey(const Key('uploadStudentCv')));
    expect(
      find.text('Vui lòng chọn tệp CV có nội dung PDF hợp lệ.'),
      findsOneWidget,
    );
    expect(profileRepo.calls, 0);
  });

  testWidgets('upload timeout blocks repeating until current CV is checked', (
    tester,
  ) async {
    profileRepo.onUpdate = () async => throw const AuthFailure(
      FailureKind.timeout,
      'Chưa xác nhận được cập nhật.',
    );
    await start(tester);
    await cv(tester, picker: () async => pdf());
    await tap(tester, find.byKey(const Key('uploadStudentCv')));
    expect(profileRepo.calls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('uploadStudentCv')))
          .onPressed,
      isNull,
    );
    await tap(tester, find.byKey(const Key('reloadStudentCv')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('uploadStudentCv')))
          .onPressed,
      isNotNull,
    );
    expect(profileRepo.calls, 1);
  });

  testWidgets(
    'successful upload with failed reload disables the stale CV view',
    (tester) async {
      var fail = false;
      dashboard.onProfile = (_) async {
        if (fail) {
          throw const AuthFailure(FailureKind.network, 'Chưa tải được CV mới.');
        }
        return StudentProfileModel.profile({
          ...profileFixture(),
          'cvUrl': 'https://example.com/old.pdf',
        });
      };
      profileRepo.onUpdate = () async => fail = true;
      await start(tester);
      await cv(tester, picker: () async => pdf());
      await tap(tester, find.byKey(const Key('uploadStudentCv')));
      expect(find.text('Chưa tải được CV mới.'), findsOneWidget);
      final view = find.descendant(
        of: find.byKey(const Key('viewStudentCv')),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.widget<OutlinedButton>(view).onPressed, isNull);
      expect(profileRepo.calls, 1);
    },
  );

  testWidgets('pending upload blocks duplicate writes and leaving the page', (
    tester,
  ) async {
    final pending = Completer<void>();
    profileRepo.onUpdate = () => pending.future;
    await start(tester);
    await cv(tester, picker: () async => pdf());
    await tester.tap(find.byKey(const Key('uploadStudentCv')));
    await tester.pump();
    expect(profileRepo.calls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('uploadStudentCv')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(StudentCvPage), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(profileRepo.calls, 1);
  });

  testWidgets('unsafe CV links are not opened or included in a snackbar', (
    tester,
  ) async {
    dashboard.onProfile = (_) async => StudentProfileModel.profile({
      ...profileFixture(),
      'cvUrl': 'javascript:private-value',
    });
    await start(tester);
    await cv(tester);
    await tap(tester, find.byKey(const Key('viewStudentCv')));
    expect(
      find.text('Chưa thể mở CV. Vui lòng kiểm tra liên kết trong hồ sơ.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-value'), findsNothing);
  });

  testWidgets(
    'name update preserves profile tab and updates the live account identity',
    (tester) async {
      var name = studentUser.fullName;
      remote.onCurrentUser = () async => namedUser(name);
      dashboard.onProfile = (_) async => StudentProfileModel.profile({
        ...profileFixture(),
        'account': {
          ...profileFixture()['account'] as Map<String, Object?>,
          'fullName': name,
        },
      });
      profileRepo.onUpdate = () async => name = profileRepo.name!;
      await start(tester);
      await tap(tester, find.byKey(const Key('editStudentProfile')));
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email · Chỉ đọc'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('profileEditName')),
        'Nguyễn Văn Bình',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('profileSave')));
      expect(profileRepo.calls, 1);
      expect(profileRepo.phone, isNull);
      expect(find.text('Hồ sơ sinh viên'), findsOneWidget);
      expect(find.text('Nguyễn Văn Bình'), findsNWidgets(2));
      expect(remote.currentUserCalls, 2);
      expect(find.textContaining('Xin chào'), findsNothing);
    },
  );

  testWidgets(
    'edit timeout preserves the form and requires a profile check before saving again',
    (tester) async {
      profileRepo.onUpdate = () async => throw const AuthFailure(
        FailureKind.timeout,
        'Chưa xác nhận được cập nhật.',
      );
      await start(tester);
      await tap(tester, find.byKey(const Key('editStudentProfile')));
      await tester.enterText(
        find.byKey(const Key('profileEditName')),
        'Tên mới',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('profileSave')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('profileSave')))
            .onPressed,
        isNull,
      );
      await tap(tester, find.byKey(const Key('profileRecheck')));
      expect(profileRepo.calls, 1);
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(
                of: find.byKey(const Key('profileEditName')),
                matching: find.byType(TextFormField),
              ),
            )
            .controller!
            .text,
        'Nguyễn Văn An',
      );
    },
  );

  testWidgets('profile, edit and CV screens support 320px and enlarged text', (
    tester,
  ) async {
    await start(tester, size: const Size(320, 720), textScale: 1.5);
    await tap(tester, find.byKey(const Key('editStudentProfile')));
    await tester.enterText(
      find.byKey(const Key('profileEditName')),
      'Nguyễn Văn An mới',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('profileSave')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('profileEditCancel')));
    await cv(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('uploadStudentCv')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile design previews', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEW')) return;
    await tester.runAsync(() async {
      for (final font in [
        ('Roboto', 'C:/Windows/Fonts/arial.ttf'),
        (
          'MaterialIcons',
          'build/flutter_assets/fonts/MaterialIcons-Regular.otf',
        ),
      ]) {
        await (FontLoader(font.$1)..addFont(
              File(
                font.$2,
              ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
            ))
            .load();
      }
    });
    dashboard.onProfile = (_) async => StudentProfileModel.profile({
      ...profileFixture(),
      'cvUrl': 'https://example.com/cv.pdf',
      'account': {
        ...profileFixture()['account'] as Map<String, Object?>,
        'phone': '0912345678',
      },
    });
    await start(tester, size: const Size(390, 1080));
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('profilePreview')),
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('.dart_tool/previews').create(recursive: true);
        await File(
          '.dart_tool/previews/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await capture('student_profile');
    await tap(tester, find.byKey(const Key('editStudentProfile')));
    await capture('student_profile_edit');
    await tester.tap(find.byKey(const Key('profileEditBack')));
    await tester.pumpAndSettle();
    await cv(tester);
    await capture('student_cv');
    expect(tester.takeException(), isNull);
  });
}
