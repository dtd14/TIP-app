import 'support/notification_fakes.dart';
import 'package:tip_app/features/profile/data/models/student_profile_model.dart';
import 'package:tip_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/app.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';

void main() {
  late FakeAuthRemote remote;
  late FakeDashboardRepository dashboard;
  late MemorySessionStorage storage;
  late AppDependencies dependencies;
  setUp(() {
    remote = FakeAuthRemote();
    dashboard = FakeDashboardRepository();
    storage = MemorySessionStorage()..value = testCredential;
    dependencies = AppDependencies.create(
      notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      notificationsRepository: FakeNotificationsRepository(),
      authRemote: remote,
      sessionStorage: storage,
      dashboardRepository: dashboard,
      opportunityRepository: dashboard,
      applicationRepository: dashboard,
      internshipRepository: dashboard,
      studentProfileRepository: dashboard,
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
        key: const Key('preview'),
        child: MyApp(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home renders real summary, navigates and allows logout', (
    tester,
  ) async {
    await start(tester);
    expect(find.textContaining('Xin chào, An'), findsOneWidget);
    expect(find.text('Đợt thực tập hiện tại'), findsOneWidget);
    expect(find.text('2180607989'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Tổng đơn'), findsOneWidget);
    expect(find.text('Đang mở'), findsOneWidget);
    expect(find.text('Trạng thái đăng ký:'), findsOneWidget);
    expect(find.textContaining('Bước'), findsNothing);
    expect(find.text('Báo cáo tuần'), findsNothing);
    expect(find.byKey(const Key('openNotifications')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav1')));
    await tester.pumpAndSettle();
    expect(find.text('Flutter Developer Intern'), findsOneWidget);
    await tester.tap(find.byKey(const Key('opportunityDetails-opportunity-1')));
    await tester.pumpAndSettle();
    expect(find.text('Tham gia phát triển ứng dụng Flutter.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('opportunityBack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav2')));
    await tester.pumpAndSettle();
    expect(find.text('Android Developer Intern'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav3')));
    await tester.pumpAndSettle();
    expect(find.text('Thực tập của tôi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav4')));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ sinh viên'), findsOneWidget);
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmLogout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
    expect(storage.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed registration displays actual backend status without a made-up stage',
    (tester) async {
      dashboard.onSummary = (_) async => DashboardSummary(
        profile: StudentProfileModel.profile(
          profileFixture(
            internships: [
              {
                'id': 'registration-ended',
                'status': 'FAILED',
                'internshipPeriod': {
                  'name': 'Đợt thực tập đã kết thúc',
                  'status': 'COMPLETED',
                  'startDate': '2025-09-01T00:00:00Z',
                  'endDate': '2025-12-31T00:00:00Z',
                  'applyEndDate': '2025-08-31T00:00:00Z',
                },
              },
            ],
          ),
        ),
        applications: const [],
        submitted: 0,
        reviewing: 0,
        accepted: 0,
      );
      await start(tester);
      expect(find.text('Đợt thực tập gần nhất'), findsOneWidget);
      expect(find.text('Đã kết thúc'), findsOneWidget);
      expect(find.text('Chưa hoàn thành'), findsOneWidget);
      expect(find.textContaining('Bước'), findsNothing);
      expect(find.text('Chuẩn bị'), findsNothing);
      expect(find.textContaining('Còn'), findsNothing);
    },
  );

  testWidgets(
    'ACTIVE personal session restores home without student API calls',
    (tester) async {
      remote.onCurrentUser = () async => nonStudentUser;
      await start(tester);
      expect(find.text('Chưa thể truy cập'), findsNothing);
      expect(find.text('Chào mừng đến TIP Career'), findsOneWidget);
      expect(dashboard.summaryCalls, 0);
      expect(find.byKey(const Key('nav2')), findsNothing);
      expect(find.byKey(const Key('nav3')), findsNothing);
      expect(find.text('Tổng đơn'), findsNothing);
      await tester.tap(find.byKey(const Key('nav1')));
      await tester.pumpAndSettle();
      expect(find.text('Flutter Developer Intern'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav4')));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ tài khoản'), findsOneWidget);
      expect(find.text(nonStudentUser.fullName), findsOneWidget);
      expect(dashboard.summaryCalls, 0);
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmLogout')));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['INACTIVE', 'SUSPENDED']) {
    testWidgets('personal account $status is restricted and can logout', (
      tester,
    ) async {
      remote.onCurrentUser = () async => AuthUser(
        id: nonStudentUser.id,
        fullName: nonStudentUser.fullName,
        accountStatus: status,
        studentAccessGranted: false,
      );
      await start(tester);
      expect(find.text('Chưa thể truy cập'), findsOneWidget);
      expect(find.byKey(const Key('nav0')), findsNothing);
      expect(dashboard.summaryCalls, 0);
      await tester.tap(find.byKey(const Key('restrictedLogout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmLogout')));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
    });
  }

  testWidgets('empty dashboard has truthful empty states', (tester) async {
    dashboard.onSummary = (_) async => dashboardFixture(empty: true);
    await start(tester);
    expect(find.textContaining('Bạn chưa được phân công'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    await tester.scrollUntilVisible(
      find.textContaining('Chưa có vị trí thực tập'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Chưa có vị trí thực tập'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and large text can scroll without overflow', (
    tester,
  ) async {
    await start(tester, size: const Size(320, 720), textScale: 1.5);
    await tester.scrollUntilVisible(
      find.text('Thực tập của tôi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  for (final status in ['INACTIVE', 'SUSPENDED', 'UNKNOWN']) {
    testWidgets('ACTIVE account with Student $status opens general home', (
      tester,
    ) async {
      remote.onCurrentUser = () async => AuthUser(
        id: studentUser.id,
        fullName: studentUser.fullName,
        accountStatus: 'ACTIVE',
        studentId: 'student-1',
        studentStatus: status,
        studentAccessGranted: true,
      );
      await start(tester);
      expect(find.text('Chưa thể truy cập'), findsNothing);
      expect(find.byKey(const Key('nav0')), findsOneWidget);
      expect(find.byKey(const Key('nav2')), findsNothing);
      expect(find.byKey(const Key('nav3')), findsNothing);
      expect(dashboard.summaryCalls, 0);
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmLogout')));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
    });
  }

  testWidgets('restored backend 403 gives restricted screen with logout', (
    tester,
  ) async {
    remote.onCurrentUser = () async => throw const ApiException(
      AuthFailure(FailureKind.inactiveAccount, 'Hồ sơ sinh viên đã bị khóa.'),
    );
    await start(tester);
    expect(find.text('Chưa thể truy cập'), findsOneWidget);
    expect(find.text('Hồ sơ sinh viên đã bị khóa.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('restrictedLogout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmLogout')));
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
  });

  testWidgets(
    'suspension detected by dashboard hides data and permits logout',
    (tester) async {
      dashboard.onSummary = (_) async => throw const AuthFailure(
        FailureKind.inactiveAccount,
        'Hồ sơ sinh viên hiện không hoạt động.',
      );
      await start(tester);
      expect(find.text('Chưa thể truy cập'), findsOneWidget);
      expect(find.byKey(const Key('nav0')), findsNothing);
      await tester.tap(find.byKey(const Key('restrictedLogout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmLogout')));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
    },
  );

  testWidgets('dashboard failure shows retry and recovers', (tester) async {
    dashboard.onSummary = (_) async => throw const AuthFailure(
      FailureKind.network,
      'Không thể kết nối máy chủ.',
    );
    await start(tester);
    expect(find.text('Không thể kết nối máy chủ.'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    dashboard.onSummary = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Đợt thực tập hiện tại'), findsOneWidget);
  });

  testWidgets('home preview', (tester) async {
    if (const bool.fromEnvironment('CAPTURE_PREVIEW')) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(
            File(
              'C:/Windows/Fonts/arial.ttf',
            ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
          );
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File(
              'build/flutter_assets/fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
          );
        await icons.load();
      });
    }
    await start(tester, size: const Size(390, 1160));
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_PREVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('.dart_tool/previews').create(recursive: true);
        await File(
          '.dart_tool/previews/home.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
