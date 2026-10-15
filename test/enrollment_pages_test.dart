import 'support/notification_fakes.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/app.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/app/theme/app_theme.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'package:tip_app/features/student_enrollment/presentation/pages/enrollment_review_page.dart';
import 'package:tip_app/features/student_enrollment/presentation/pages/student_enrollment_page.dart';
import 'package:tip_app/features/student_enrollment/presentation/widgets/enrollment_form.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';
import 'support/enrollment_fakes.dart';
import 'nest_auth_remote_data_source_test.dart' show meFixture, activeStudent;

void main() {
  late FakeEnrollmentRepository repo;
  setUp(() => repo = FakeEnrollmentRepository());
  Future<void> page(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const bool.fromEnvironment('CAPTURE_PREVIEW')
        ? const Size(390, 1160)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('enrollmentPreview'),
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEW')) return;
    await tester.runAsync(() async {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            'C:/Windows/Fonts/arial.ttf',
          ).readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            'build/flutter_assets/fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      await icons.load();
    });
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('enrollmentPreview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('.dart_tool/previews').create(recursive: true);
      await File(
        '.dart_tool/previews/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget ownPage() => StudentEnrollmentPage(
    user: nonStudentUser,
    repository: repo,
    onReloadAccount: () {},
    onRestricted: (_) {},
  );
  testWidgets(
    'pending request hides new form; cancel confirmation preserves history',
    (tester) async {
      repo.items = [enrollment()];
      await page(tester, ownPage());
      expect(find.byKey(const Key('enrollmentSubmit')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('cancel-request-1')));
      await tester.tap(find.byKey(const Key('cancel-request-1')));
      await tester.pumpAndSettle();
      expect(repo.cancelCalls, 0);
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pumpAndSettle();
      expect(repo.cancelCalls, 1);
      expect(find.byKey(const Key('enrollmentSubmit')), findsOneWidget);
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'school major pairing, required fields and semester produce a single request',
    (tester) async {
      await page(tester, ownPage());
      await capture(tester, 'student_enrollment');
      await tester.ensureVisible(find.byKey(const Key('enrollmentSchool')));
      await tester.tap(find.byKey(const Key('enrollmentSchool')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('school-school-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('enrollmentMajor-school-1')),
      );
      await tester.tap(find.byKey(const Key('enrollmentMajor-school-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Công nghệ thông tin').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('enrollmentStudentCode')),
        'SV001',
      );
      await tester.enterText(
        find.byKey(const Key('enrollmentClass')),
        'CNTT01',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('enrollmentSubmit')));
      await tester.tap(find.byKey(const Key('enrollmentSubmit')));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      expect(repo.submitted!.universityId, 'school-1');
      expect(repo.submitted!.majorId, 'major-school-1');
      expect(repo.submitted!.studentCode, 'SV001');
      expect(repo.submitted!.className, 'CNTT01');
      expect(repo.submitted!.semester, 1);
      expect(find.byKey(const Key('enrollmentSubmit')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late majors cannot replace the newly selected university majors',
    (tester) async {
      final old = Completer<List<EnrollmentMajor>>();
      repo.onMajors = (id) => id == 'school-1'
          ? old.future
          : Future.value(const [
              EnrollmentMajor(id: 'major-2', name: 'Ngành trường mới'),
            ]);
      await page(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: EnrollmentForm(
              repository: repo,
              busy: false,
              onSubmit: (_) {},
              onRestricted: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('enrollmentSchool')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('school-school-1')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('enrollmentSchool')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('school-school-2')));
      await tester.pumpAndSettle();
      old.complete(const [EnrollmentMajor(id: 'old', name: 'Ngành trường cũ')]);
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const Key('enrollmentMajor-school-2')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(dropdown.items!.map((e) => e.value), ['major-2']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('history and form fit small screen with enlarged text', (
    tester,
  ) async {
    repo.items = [enrollment(status: 'REJECTED')];
    await page(tester, ownPage(), scale: 1.5);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Lý do từ chối: Mã sinh viên chưa đúng'),
    );
    await tester.pumpAndSettle();
  });
  testWidgets(
    'school search ignores stale results and scrolls with keyboard on a small screen',
    (tester) async {
      final stale = Completer<List<EnrollmentSchool>>();
      repo.onUniversities = (keyword) => keyword == 'old'
          ? stale.future
          : Future.value([
              EnrollmentSchool(id: 'new', name: 'Đại học $keyword'),
            ]);
      await page(tester, ownPage(), scale: 1.5);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('enrollmentSchool')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('enrollmentSchool')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('enrollmentSchoolSearch')),
        'old',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.byKey(const Key('enrollmentSchoolSearch')),
        'new',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      stale.complete(const [EnrollmentSchool(id: 'old', name: 'Kết quả cũ')]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('school-old')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('school-new')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('admin must enter rejection reason before review request', (
    tester,
  ) async {
    repo.items = [enrollment()];
    await page(
      tester,
      EnrollmentReviewPage(
        user: schoolAdmin,
        repository: repo,
        onRestricted: (_) {},
      ),
    );
    await capture(tester, 'enrollment_review');
    await tester.ensureVisible(find.byKey(const Key('reject-request-1')));
    await tester.tap(find.byKey(const Key('reject-request-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enrollmentReviewConfirm')));
    await tester.pumpAndSettle();
    expect(repo.reviewCalls, 0);
    expect(find.text('Vui lòng nhập lý do từ chối.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('enrollmentRejectionReason')),
      'Sai MSSV',
    );
    await tester.tap(find.byKey(const Key('enrollmentReviewConfirm')));
    await tester.pumpAndSettle();
    expect(repo.reviewCalls, 1);
    expect(repo.reviewedReason, 'Sai MSSV');
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin confirms real school enrollment before approval', (
    tester,
  ) async {
    repo.items = [enrollment()];
    await page(
      tester,
      EnrollmentReviewPage(
        user: schoolAdmin,
        repository: repo,
        onRestricted: (_) {},
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('approve-request-1')));
    await tester.tap(find.byKey(const Key('approve-request-1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('enrollmentReviewConfirm')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('enrollmentVerified')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enrollmentReviewConfirm')));
    await tester.pumpAndSettle();
    expect(repo.reviewCalls, 1);
    expect(repo.approved, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'approval reloads me into Student home without re-login or token replacement',
    (tester) async {
      final remote = FakeAuthRemote()
        ..onCurrentUser = () async => AuthUserModel.fromMeResponse(meFixture());
      final storage = MemorySessionStorage()..value = testCredential;
      final dependencies = AppDependencies.create(
        notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
        notificationsRepository: FakeNotificationsRepository(),
        authRemote: remote,
        sessionStorage: storage,
        dashboardRepository: FakeDashboardRepository(),
        studentEnrollmentRepository: repo,
      );
      addTearDown(dependencies.dispose);
      await page(tester, MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nav2')), findsNothing);
      await tester.tap(find.byTooltip('Menu tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('enrollmentMenu')));
      await tester.pumpAndSettle();
      remote.onCurrentUser = () async =>
          AuthUserModel.fromMeResponse(meFixture(student: activeStudent));
      await tester.tap(find.byKey(const Key('enrollmentReloadAccount')));
      await tester.pumpAndSettle();
      expect(remote.loginCalls, 0);
      expect(remote.currentUserCalls, 2);
      expect(storage.writes, 0);
      expect(find.byKey(const Key('nav2')), findsOneWidget);
      expect(find.text('Đợt thực tập hiện tại'), findsOneWidget);
      expect(find.byKey(const Key('enrollmentReloadAccount')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Student profile edits personal fields and retains read-only academic fields',
    (tester) async {
      final profileRepo = FakeStudentProfileRepository();
      final remote = FakeAuthRemote();
      final dependencies = AppDependencies.create(
        notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
        notificationsRepository: FakeNotificationsRepository(),
        authRemote: remote,
        sessionStorage: MemorySessionStorage()..value = testCredential,
        dashboardRepository: FakeDashboardRepository(),
        studentProfileRepository: profileRepo,
      );
      addTearDown(dependencies.dispose);
      await page(tester, MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav4')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('editStudentProfile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editStudentProfile')));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.enterText(
        find.byKey(const Key('profileEditName')),
        'Tên mới',
      );
      await tester.enterText(
        find.byKey(const Key('profileEditPhone')),
        '0901234567',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('profileSave')));
      await tester.tap(find.byKey(const Key('profileSave')));
      await tester.pumpAndSettle();
      expect(profileRepo.calls, 1);
      expect(profileRepo.name, 'Tên mới');
      expect(profileRepo.phone, '0901234567');
      expect(remote.currentUserCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
