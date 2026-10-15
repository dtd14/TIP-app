import 'support/notification_fakes.dart';
import 'package:tip_app/features/opportunities/data/models/opportunity_model.dart';
import 'package:tip_app/features/internships/data/models/internship_model.dart';
import 'package:tip_app/features/profile/data/models/student_profile_model.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
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
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';

void main() {
  late FakeAuthRemote remote;
  late FakeDashboardRepository repository;
  late AppDependencies dependencies;
  setUp(() {
    remote = FakeAuthRemote();
    repository = FakeDashboardRepository();
    dependencies = AppDependencies.create(
      notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      notificationsRepository: FakeNotificationsRepository(),
      authRemote: remote,
      sessionStorage: MemorySessionStorage()..value = testCredential,
      dashboardRepository: repository,
      opportunityRepository: repository,
      applicationRepository: repository,
      internshipRepository: repository,
      studentProfileRepository: repository,
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
        key: const Key('internshipPreview'),
        child: MyApp(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav3')));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> period(WidgetTester tester) =>
      tap(tester, find.byKey(const Key('internshipPeriod-registration-1')));
  Future<void> placement(WidgetTester tester) =>
      tap(tester, find.byKey(const Key('internshipPlacement-placement-1')));

  testWidgets(
    'filters count own registrations and distinguish completed students from ended periods',
    (tester) async {
      repository.onProfile = (_) async => StudentProfileModel.profile(
        profileFixture(
          internships: [
            {
              'id': 'registration-1',
              'status': 'APPLYING',
              'internshipPeriod': internshipPeriodFixture,
            },
            {
              'id': 'registration-complete',
              'status': 'COMPLETED',
              'internshipPeriod': {
                ...internshipPeriodFixture,
                'id': 'period-complete',
                'status': 'COMPLETED',
                'name': 'Đợt đã hoàn thành 2025',
                'startDate': '2025-09-01T00:00:00Z',
              },
            },
            {
              'id': 'registration-failed',
              'status': 'FAILED',
              'internshipPeriod': {
                ...internshipPeriodFixture,
                'id': 'period-failed',
                'status': 'COMPLETED',
                'name': 'Đợt chưa hoàn thành 2024',
                'startDate': '2024-09-01T00:00:00Z',
              },
            },
          ],
        ),
      );
      await start(tester);
      expect(find.text('Tất cả 3'), findsOneWidget);
      expect(find.text('Đã hoàn thành 1'), findsOneWidget);
      expect(find.text('Đang mở / Hiện tại 1'), findsOneWidget);
      await tap(tester, find.byKey(const Key('internshipFilter-COMPLETED')));
      expect(
        find.byKey(const Key('internshipPeriod-registration-complete')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('internshipPeriod-registration-failed')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('internshipPeriod-registration-1')),
        findsNothing,
      );
      expect(find.text('Báo cáo tuần'), findsNothing);
      expect(find.textContaining('Điểm:'), findsNothing);
    },
  );

  testWidgets(
    'own periods remain visible if placement API fails and retry only repeats placement read',
    (tester) async {
      repository.onPlacements = (_, _) async =>
          throw const AuthFailure(FailureKind.network, 'Chưa tải được vị trí.');
      await start(tester);
      expect(
        find.byKey(const Key('internshipPeriod-registration-1')),
        findsOneWidget,
      );
      expect(find.text('Chưa tải được vị trí.'), findsOneWidget);
      repository.onPlacements = null;
      await tap(tester, find.text('Thử lại'));
      expect(repository.profileCalls, 1);
      expect(repository.placementQueries, [(1, null), (1, null)]);
      expect(
        find.byKey(const Key('internshipPlacement-placement-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'period detail shows real requirements and personal status without invented progress',
    (tester) async {
      await start(tester);
      await period(tester);
      expect(find.text('Chi tiết đợt thực tập'), findsOneWidget);
      expect(find.text('240 giờ'), findsOneWidget);
      expect(find.text('12 tuần'), findsOneWidget);
      expect(find.text('Đang nộp hồ sơ'), findsOneWidget);
      expect(find.text('Mốc thời gian'), findsOneWidget);
      expect(repository.placementQueries.last, (1, 'registration-1'));
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Hạn nộp báo cáo'), findsNothing);
      await tap(tester, find.byKey(const Key('periodApplications')));
      expect(find.text('Đơn ứng tuyển của tôi'), findsOneWidget);
      expect(repository.applicationQueries.last, (1, null));
    },
  );

  testWidgets(
    'removed registration blocks detail and does not request its placements',
    (tester) async {
      await start(tester);
      repository.onRegistration = (_) async => throw const AuthFailure(
        FailureKind.validation,
        'Đợt không còn trong hồ sơ của bạn.',
      );
      await period(tester);
      expect(find.text('Đợt không còn trong hồ sơ của bạn.'), findsOneWidget);
      expect(find.text('Yêu cầu thời lượng'), findsNothing);
      expect(repository.placementQueries, [(1, null)]);
    },
  );

  testWidgets('placement pagination keeps cards and retries a failed page', (
    tester,
  ) async {
    var fail = true;
    repository.onPlacements = (page, _) async {
      if (page == 2 && fail) {
        throw const AuthFailure(FailureKind.network, 'Không có mạng.');
      }
      return PageSlice(
        items: [
          InternshipModel.internshipPlacement({
            ...placementDetailFixture(),
            'id': 'placement-$page',
          }),
        ],
        total: 2,
        page: page,
        limit: 1,
      );
    };
    await start(tester);
    await tap(tester, find.text('Tải thêm vị trí'));
    expect(
      find.byKey(const Key('internshipPlacement-placement-1')),
      findsOneWidget,
    );
    expect(find.text('Không có mạng.'), findsOneWidget);
    fail = false;
    await tap(tester, find.text('Thử lại'));
    expect(
      find.byKey(const Key('internshipPlacement-placement-2')),
      findsOneWidget,
    );
    expect(repository.placementQueries, [(1, null), (2, null), (2, null)]);
  });

  testWidgets(
    'placement detail displays both assigned supervisors and links to period and application',
    (tester) async {
      await start(tester);
      await placement(tester);
      expect(find.text('Chi tiết vị trí thực tập'), findsOneWidget);
      expect(find.text('Nguyễn Tuấn Anh'), findsOneWidget);
      expect(find.text('Trần Văn C'), findsOneWidget);
      expect(find.text('mentor@example.com'), findsOneWidget);
      expect(find.text('Đang thực tập'), findsOneWidget);
      expect(find.text('Nộp nhật ký Tuần 4'), findsNothing);
      await tap(tester, find.byKey(const Key('placementPeriod')));
      expect(find.text('Chi tiết đợt thực tập'), findsOneWidget);
      await tester.tap(find.byKey(const Key('internshipBack')));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('placementApplication')));
      expect(find.text('Chi tiết ứng tuyển'), findsOneWidget);
    },
  );

  testWidgets(
    'direct placement omits absent sources, progress and unsupported work data',
    (tester) async {
      repository.onPlacement = (_) async =>
          InternshipModel.internshipPlacement({
            ...placementDetailFixture(linked: false),
            'universitySupervisor': null,
            'companySupervisor': null,
          });
      await start(tester);
      await placement(tester);
      expect(find.text('Chưa phân công'), findsNWidgets(2));
      expect(find.byKey(const Key('placementPeriod')), findsNothing);
      expect(find.byKey(const Key('placementApplication')), findsNothing);
      expect(find.byKey(const Key('placementOpportunity')), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('giờ làm việc'), findsNothing);
      expect(find.text('Hợp đồng'), findsNothing);
    },
  );

  testWidgets(
    'company page shows actual company data and opportunities enter the confirmation flow',
    (tester) async {
      repository.onOpportunity = (_) async => OpportunityModel.opportunity({
        ...opportunityDetailFixture,
        'applicationDeadline': '2099-10-31T00:00:00Z',
      });
      await start(tester);
      await placement(tester);
      await tap(tester, find.byKey(const Key('placementCompanyLogo')));
      expect(find.text('Doanh nghiệp'), findsOneWidget);
      expect(find.text('Phát triển phần mềm'), findsNWidgets(2));
      expect(find.text('1 cơ hội đang mở'), findsOneWidget);
      expect(find.text('Theo dõi công ty'), findsNothing);
      expect(find.text('Gửi tin nhắn'), findsNothing);
      await tap(
        tester,
        find.byKey(const Key('opportunityDetails-opportunity-1')),
      );
      await tap(tester, find.byKey(const Key('applyOpportunity')));
      expect(find.text('Xác nhận ứng tuyển'), findsOneWidget);
      expect(repository.applyCalls, 0);
    },
  );

  testWidgets(
    'company opportunity failure preserves company info and retries only the failed resource',
    (tester) async {
      repository.onCompanyOpportunities = (_) async =>
          throw const AuthFailure(FailureKind.network, 'Chưa tải được cơ hội.');
      await start(tester);
      await placement(tester);
      await tap(tester, find.byKey(const Key('placementCompanyLogo')));
      expect(find.text('https://example.com'), findsOneWidget);
      expect(find.text('Chưa tải được cơ hội.'), findsOneWidget);
      final companyCalls = repository.companyCalls;
      repository.onCompanyOpportunities = null;
      await tap(tester, find.text('Thử lại'));
      expect(repository.companyCalls, companyCalls);
      expect(repository.companyOpportunityCalls, 2);
      expect(find.text('1 cơ hội đang mở'), findsOneWidget);
    },
  );

  testWidgets(
    'missing linked opportunity keeps placement detail and shows backend guidance',
    (tester) async {
      repository.onOpportunity = (_) async => throw const AuthFailure(
        FailureKind.server,
        'Cơ hội không còn khả dụng.',
      );
      await start(tester);
      await placement(tester);
      await tap(tester, find.byKey(const Key('placementOpportunity')));
      expect(find.text('Cơ hội không còn khả dụng.'), findsOneWidget);
      expect(find.text('Chi tiết vị trí thực tập'), findsOneWidget);
      expect(find.text('Chi tiết cơ hội'), findsNothing);
    },
  );

  testWidgets(
    'expired session clears internship navigation on foreground validation',
    (tester) async {
      await start(tester);
      await placement(tester);
      remote.onCurrentUser = () async => throw const ApiException(
        AuthFailure(FailureKind.sessionExpired, 'Phiên đã hết hạn.'),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết vị trí thực tập'), findsNothing);
      expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
    },
  );

  testWidgets('internship pages support narrow screens with enlarged text', (
    tester,
  ) async {
    await start(tester, size: const Size(320, 720), textScale: 1.5);
    await period(tester);
    await tap(tester, find.byKey(const Key('internshipPlacement-placement-1')));
    await tap(tester, find.byKey(const Key('placementCompanyLogo')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('opportunityDetails-opportunity-1')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('internship design previews', (tester) async {
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
    await start(tester, size: const Size(390, 1080));
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('internshipPreview')),
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

    await capture('internships');
    await period(tester);
    await capture('internship_period');
    await tap(tester, find.byKey(const Key('internshipPlacement-placement-1')));
    await capture('internship_placement');
    await tap(tester, find.byKey(const Key('placementCompanyLogo')));
    await capture('internship_company');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'internship tab can load independently of a failed dashboard summary',
    (tester) async {
      repository.onSummary = (_) async => throw const AuthFailure(
        FailureKind.network,
        'Chưa tải được trang chủ.',
      );
      await start(tester);
      expect(find.text('Thực tập của tôi'), findsOneWidget);
      expect(
        find.byKey(const Key('internshipPeriod-registration-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('internshipPlacement-placement-1')),
        findsOneWidget,
      );
      expect(repository.profileCalls, 1);
    },
  );

  testWidgets(
    'empty internship data has no sample periods, placements or completion claims',
    (tester) async {
      repository.onProfile = (_) async =>
          StudentProfileModel.profile(profileFixture(internships: []));
      repository.onPlacements = (page, _) async =>
          PageSlice(items: [], total: 0, page: page, limit: 20);
      await start(tester);
      expect(find.text('Tất cả 0'), findsOneWidget);
      expect(
        find.text('Bạn chưa có vị trí thực tập được phân công.'),
        findsOneWidget,
      );
      expect(find.text('240 giờ'), findsNothing);
      expect(find.text('Android Developer Intern'), findsNothing);
      expect(find.text('0 vị trí trong hồ sơ'), findsOneWidget);
    },
  );

  testWidgets(
    'placement permission denial stays in the app with retry guidance',
    (tester) async {
      repository.onPlacement = (_) async => throw const AuthFailure(
        FailureKind.forbidden,
        'Bạn chưa được phép xem vị trí này.',
      );
      await start(tester);
      await placement(tester);
      expect(find.text('Bạn chưa được phép xem vị trí này.'), findsOneWidget);
      expect(find.text('Thông tin thực tập'), findsNothing);
      expect(find.text('Chưa thể truy cập'), findsNothing);
      expect(repository.placementCalls, 1);
    },
  );
}
