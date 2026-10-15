import 'support/notification_fakes.dart';
import 'package:tip_app/features/opportunities/data/models/opportunity_model.dart';
import 'package:tip_app/features/applications/data/models/application_model.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'dart:async';
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

OpportunityOverview opportunity({
  String id = 'opportunity-1',
  String type = 'INTERNSHIP',
  String title = 'Flutter Developer Intern',
  String location = 'TP. Hồ Chí Minh',
  DateTime? deadline,
}) => OpportunityModel.publicOpportunity({
  ...opportunityFixture,
  'id': id,
  'type': type,
  'title': title,
  'location': location,
  'applicationDeadline': deadline?.toUtc().toIso8601String(),
});

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
        key: const Key('opportunityPreview'),
        child: MyApp(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav1')));
    await tester.pumpAndSettle();
  }

  Future<void> details(WidgetTester tester) async {
    final button = find.byKey(const Key('opportunityDetails-opportunity-1'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  void availableDetail() {
    repository.onOpportunity = (_) async => OpportunityModel.opportunity({
      ...opportunityDetailFixture,
      'applicationDeadline': DateTime.now()
          .add(const Duration(days: 30))
          .toUtc()
          .toIso8601String(),
    });
  }

  Future<void> confirmApplication(
    WidgetTester tester, {
    bool settle = true,
  }) async {
    await tester.tap(find.byKey(const Key('applyOpportunity')));
    await tester.pumpAndSettle();
    expect(repository.applyCalls, 0);
    final consent = find.byType(CheckboxListTile);
    await tester.ensureVisible(consent);
    await tester.pumpAndSettle();
    await tester.tap(consent);
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirmApplication')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets(
    'type and keyword filters operate on loaded results and keep total',
    (tester) async {
      repository.onOpportunities = (page) async => PageSlice(
        items: [
          opportunity(),
          opportunity(
            id: 'micro-1',
            type: 'MICRO_INTERNSHIP',
            title: 'Frontend Micro Project',
            location: 'Hà Nội',
          ),
        ],
        total: 42,
        page: page,
        limit: 12,
      );
      await start(tester);
      expect(find.text('Tất cả 42'), findsOneWidget);
      expect(find.text('Đã tải 2/42 cơ hội'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('opportunityType-MICRO_INTERNSHIP')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('opportunityType-MICRO_INTERNSHIP')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Frontend Micro Project'), findsOneWidget);
      expect(find.text('Flutter Developer Intern'), findsNothing);
      expect(find.text('1 kết quả trong 2 cơ hội đã tải'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('opportunityType-ALL')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opportunityType-ALL')));
      await tester.enterText(
        find.byKey(const Key('opportunitySearch')),
        'hà nội',
      );
      await tester.pumpAndSettle();
      expect(find.text('Frontend Micro Project'), findsOneWidget);
      expect(find.text('Flutter Developer Intern'), findsNothing);
      expect(repository.opportunityPages, [1]);
    },
  );

  testWidgets(
    'location filter sheet applies and clears without losing search',
    (tester) async {
      await start(tester);
      await tester.tap(find.byTooltip('Lọc cơ hội'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('opportunityLocationFilter')),
        'Hà Nội',
      );
      await tester.tap(find.text('Áp dụng bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('0 kết quả trong 1 cơ hội đã tải'), findsOneWidget);
      await tester.tap(find.byTooltip('Lọc cơ hội'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('Flutter Developer Intern'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pagination failure preserves cards and retries the same page', (
    tester,
  ) async {
    var fail = true;
    repository.onOpportunities = (page) async {
      if (page == 2 && fail) {
        throw const AuthFailure(FailureKind.network, 'Không có mạng.');
      }
      return PageSlice(
        items: [
          opportunity(
            id: page == 1 ? 'opportunity-1' : 'next-1',
            title: page == 1
                ? 'Flutter Developer Intern'
                : 'Android Developer Intern',
          ),
        ],
        total: 2,
        page: page,
        limit: 1,
      );
    };
    await start(tester);
    await tester.ensureVisible(find.text('Tải thêm cơ hội'));
    await tester.tap(find.text('Tải thêm cơ hội'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter Developer Intern'), findsOneWidget);
    expect(find.text('Không có mạng.'), findsOneWidget);
    fail = false;
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Android Developer Intern'), findsOneWidget);
    expect(repository.opportunityPages, [1, 2, 2]);
    expect(find.text('Tải thêm cơ hội'), findsNothing);
  });

  testWidgets(
    'public account sees full-page snapshot without student requests',
    (tester) async {
      remote.onCurrentUser = () async => nonStudentUser;
      await start(tester);
      await details(tester);
      expect(find.text('Chi tiết cơ hội'), findsOneWidget);
      expect(find.text('5 vị trí'), findsOneWidget);
      expect(
        find.text('Cần hồ sơ sinh viên hợp lệ để ứng tuyển.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('applyOpportunity')))
            .onPressed,
        isNull,
      );
      expect(repository.detailCalls, 0);
      expect(repository.companyCalls, 0);
      expect(repository.applyCalls, 0);
      expect(find.textContaining('Match'), findsNothing);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
      expect(find.byKey(const Key('openNotifications')), findsOneWidget);
      await tester.tap(find.byKey(const Key('opportunityBack')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('opportunitySearch')), findsOneWidget);
    },
  );

  testWidgets(
    'student detail shows actual company data and missing deadline disables apply',
    (tester) async {
      await start(tester);
      await details(tester);
      expect(
        find.text('Doanh nghiệp chưa cập nhật hạn ứng tuyển.'),
        findsOneWidget,
      );
      expect(find.text('Phát triển phần mềm'), findsOneWidget);
      expect(find.text('https://example.com'), findsOneWidget);
      expect(repository.detailCalls, 1);
      expect(repository.companyCalls, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('applyOpportunity')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('apply disables duplicates and updates dashboard on return', (
    tester,
  ) async {
    availableDetail();
    final pending = Completer<ApplicationOverview>();
    repository.onApply = (_) => pending.future;
    await start(tester);
    await details(tester);
    await confirmApplication(tester, settle: false);
    await tester.tap(find.byKey(const Key('confirmApplication')));
    expect(repository.applyCalls, 1);
    pending.complete(ApplicationModel.application(applicationFixture));
    await tester.pumpAndSettle();
    expect(find.text('Đã ứng tuyển'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('applyOpportunity')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('opportunityBack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opportunitySearch')), findsOneWidget);
    expect(repository.summaryCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail failure keeps snapshot but blocks apply until fresh retry',
    (tester) async {
      repository.onOpportunity = (_) async =>
          throw const AuthFailure(FailureKind.network, 'Không có mạng.');
      await start(tester);
      await details(tester);
      expect(find.text('Flutter Developer Intern'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('applyOpportunity')))
            .onPressed,
        isNull,
      );
      availableDetail();
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('applyOpportunity')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'application denial stays on confirmation and does not report success',
    (tester) async {
      availableDetail();
      repository.onApply = (_) async => throw const AuthFailure(
        FailureKind.forbidden,
        'Bạn chưa được phép ứng tuyển.',
      );
      await start(tester);
      await details(tester);
      await confirmApplication(tester);
      expect(find.text('Bạn chưa được phép ứng tuyển.'), findsOneWidget);
      expect(find.text('Đã ứng tuyển'), findsNothing);
      expect(repository.applyCalls, 1);
      expect(find.text('Chưa thể truy cập'), findsNothing);
    },
  );

  testWidgets('locked account removes detail and displays restriction', (
    tester,
  ) async {
    availableDetail();
    repository.onApply = (_) async => throw const AuthFailure(
      FailureKind.inactiveAccount,
      'Tài khoản đã bị khóa.',
    );
    await start(tester);
    await details(tester);
    await confirmApplication(tester);
    expect(find.text('Chi tiết cơ hội'), findsNothing);
    expect(find.text('Chưa thể truy cập'), findsOneWidget);
    expect(find.byKey(const Key('restrictedLogout')), findsOneWidget);
  });

  testWidgets('expired session while on detail clears the navigation stack', (
    tester,
  ) async {
    await start(tester);
    await details(tester);
    remote.onCurrentUser = () async => throw const ApiException(
      AuthFailure(FailureKind.sessionExpired, 'Phiên đã hết hạn.'),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết cơ hội'), findsNothing);
    expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
  });

  testWidgets('list and detail support narrow screens with enlarged text', (
    tester,
  ) async {
    availableDetail();
    await start(tester, size: const Size(320, 720), textScale: 1.5);
    await details(tester);
    await tester.scrollUntilVisible(
      find.text('THÔNG TIN DOANH NGHIỆP'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opportunity design previews', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEW')) return;
    await tester.runAsync(() async {
      for (final font in [
        ('Roboto', 'C:/Windows/Fonts/arial.ttf'),
        (
          'MaterialIcons',
          'build/flutter_assets/fonts/MaterialIcons-Regular.otf',
        ),
      ]) {
        final loader = FontLoader(font.$1)
          ..addFont(
            File(
              font.$2,
            ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
          );
        await loader.load();
      }
    });
    availableDetail();
    repository.onOpportunities = (page) async => PageSlice(
      items: [
        opportunity(deadline: DateTime.now().add(const Duration(days: 30))),
        opportunity(
          id: 'micro-1',
          type: 'MICRO_INTERNSHIP',
          title: 'Frontend Web Developer — Micro Project',
          location: 'Hà Nội',
          deadline: DateTime.now().add(const Duration(days: 18)),
        ),
      ],
      total: 2,
      page: 1,
      limit: 12,
    );
    await start(tester, size: const Size(390, 1080));
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('opportunityPreview')),
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

    await capture('opportunities');
    await details(tester);
    await capture('opportunity_detail');
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back returns from detail and refreshes after applying', (
    tester,
  ) async {
    availableDetail();
    await start(tester);
    await details(tester);
    await confirmApplication(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết cơ hội'), findsNothing);
    expect(find.byKey(const Key('opportunitySearch')), findsOneWidget);
    expect(repository.summaryCalls, 2);
  });

  testWidgets(
    'company failure can retry without blocking a valid opportunity',
    (tester) async {
      availableDetail();
      repository.onCompany = (_) async => throw const AuthFailure(
        FailureKind.network,
        'Chưa tải được doanh nghiệp.',
      );
      await start(tester);
      await details(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('applyOpportunity')))
            .onPressed,
        isNotNull,
      );
      expect(find.text('Chưa tải được doanh nghiệp.'), findsOneWidget);
      repository.onCompany = null;
      await tester.ensureVisible(find.text('Tải lại doanh nghiệp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tải lại doanh nghiệp'));
      await tester.pumpAndSettle();
      expect(find.text('Phát triển phần mềm'), findsOneWidget);
      expect(repository.companyCalls, 2);
    },
  );

  for (final state in ['CLOSED', 'EXPIRED']) {
    testWidgets('fresh $state opportunity cannot be applied to', (
      tester,
    ) async {
      repository.onOpportunity = (_) async => OpportunityModel.opportunity({
        ...opportunityDetailFixture,
        'status': state == 'CLOSED' ? 'CLOSED' : 'OPEN',
        'applicationDeadline': DateTime.now()
            .add(Duration(days: state == 'EXPIRED' ? -1 : 30))
            .toUtc()
            .toIso8601String(),
      });
      await start(tester);
      await details(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('applyOpportunity')))
            .onPressed,
        isNull,
      );
      expect(repository.applyCalls, 0);
    });
  }
}
