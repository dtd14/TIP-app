import 'support/notification_fakes.dart';
import 'package:tip_app/features/opportunities/data/models/opportunity_model.dart';
import 'package:tip_app/features/applications/data/models/application_model.dart';
import 'package:tip_app/features/profile/data/models/student_profile_model.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
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
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';
import 'package:tip_app/features/applications/presentation/widgets/application_withdrawal_sheet.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';

void main() {
  late FakeAuthRemote remote;
  late FakeDashboardRepository repository;
  late AppDependencies dependencies;
  setUp(() {
    remote = FakeAuthRemote();
    repository = FakeDashboardRepository();
    repository.onOpportunity = (_) async => OpportunityModel.opportunity({
      ...opportunityDetailFixture,
      'applicationDeadline': '2099-10-31T00:00:00Z',
    });
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
    int tab = 1,
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
        key: const Key('applicationPreview'),
        child: MyApp(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('nav$tab')));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> confirmation(WidgetTester tester) async {
    await tapVisible(
      tester,
      find.byKey(const Key('opportunityDetails-opportunity-1')),
    );
    await tapVisible(tester, find.byKey(const Key('applyOpportunity')));
  }

  Future<void> detail(WidgetTester tester) async {
    // With enlarged text the card may be taller than the viewport. Tap its
    // visible title rather than a center that can fall behind the navbar.
    await tapVisible(
      tester,
      find.descendant(
        of: find.byKey(const Key('application-application-1')),
        matching: find.text('Android Developer Intern'),
      ),
    );
  }

  Future<void> consent(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(const Key('applicationConsent')));
  }

  testWidgets(
    'opening confirmation and canceling does not submit; current profile is loaded',
    (tester) async {
      await start(tester);
      await confirmation(tester);
      expect(repository.applyCalls, 0);
      expect(repository.profileCalls, 1);
      expect(find.text('Hồ sơ dùng ứng tuyển'), findsOneWidget);
      expect(
        find.text('2180607989'),
        findsNothing,
      ); // MSSV is displayed with its label.
      expect(find.textContaining('MSSV: 2180607989'), findsOneWidget);
      expect(find.text('Công nghệ thông tin'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirmApplication')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết cơ hội'), findsOneWidget);
      expect(repository.applyCalls, 0);
    },
  );

  testWidgets(
    'CV is optional according to the API; consent enables one submit',
    (tester) async {
      await start(tester);
      await confirmation(tester);
      await consent(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirmApplication')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('confirmApplication')));
      await tester.pumpAndSettle();
      expect(repository.applyCalls, 1);
      expect(find.text('Đã ứng tuyển'), findsOneWidget);
      expect(find.text('Xác nhận ứng tuyển'), findsNothing);
    },
  );

  testWidgets(
    'profile read failure blocks submit; retry rereads profile and opportunity',
    (tester) async {
      repository.onProfile = (_) async =>
          throw const AuthFailure(FailureKind.network, 'Chưa tải được hồ sơ.');
      await start(tester);
      await confirmation(tester);
      expect(find.text('Chưa tải được hồ sơ.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirmApplication')))
            .onPressed,
        isNull,
      );
      repository.onProfile = null;
      await tapVisible(tester, find.text('Kiểm tra lại hồ sơ'));
      expect(repository.profileCalls, 2);
      expect(find.byKey(const Key('applicationConsent')), findsOneWidget);
      expect(repository.applyCalls, 0);
    },
  );

  testWidgets('opportunity closing during confirmation prevents posting', (
    tester,
  ) async {
    await start(tester);
    await tapVisible(
      tester,
      find.byKey(const Key('opportunityDetails-opportunity-1')),
    );
    repository.onOpportunity = (_) async => OpportunityModel.opportunity({
      ...opportunityDetailFixture,
      'status': 'CLOSED',
    });
    await tapVisible(tester, find.byKey(const Key('applyOpportunity')));
    await consent(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirmApplication')))
          .onPressed,
      isNull,
    );
    expect(repository.applyCalls, 0);
  });

  testWidgets(
    'uncertain submit disables repeating and can navigate to own applications',
    (tester) async {
      repository.onApply = (_) async => throw const AuthFailure(
        FailureKind.timeout,
        'Chưa xác nhận được kết quả gửi đơn.',
      );
      await start(tester);
      await confirmation(tester);
      await consent(tester);
      await tester.tap(find.byKey(const Key('confirmApplication')));
      await tester.pumpAndSettle();
      expect(repository.applyCalls, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirmApplication')))
            .onPressed,
        isNull,
      );
      await tapVisible(tester, find.byKey(const Key('checkMyApplications')));
      expect(find.text('Đơn ứng tuyển của tôi'), findsOneWidget);
      expect(repository.applyCalls, 1);
      expect(repository.applicationQueries, [(1, null)]);
    },
  );

  testWidgets(
    'foreground validation preserves confirmation and consent for unchanged user',
    (tester) async {
      await start(tester);
      await confirmation(tester);
      await consent(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận ứng tuyển'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('applicationConsent')),
            )
            .value,
        isTrue,
      );
      expect(remote.currentUserCalls, 2);
      expect(repository.applyCalls, 0);
    },
  );

  testWidgets(
    'own list filter uses server status, exact total and correct pagination after failure',
    (tester) async {
      var fail = true;
      repository.onFilteredApplications = (page, status) async {
        if (page == 2 && fail) {
          throw const AuthFailure(FailureKind.network, 'Mất kết nối.');
        }
        return PageSlice(
          items: [
            ApplicationModel.application({
              ...applicationDetailFixture(status: status ?? 'PENDING'),
              'id': 'application-$page',
            }),
          ],
          total: 2,
          page: page,
          limit: 1,
        );
      };
      await start(tester, tab: 2);
      expect(find.text('2 đơn ứng tuyển'), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const Key('applicationFilter-REVIEWING')),
      );
      await tapVisible(tester, find.text('Tải thêm đơn'));
      expect(
        find.byKey(const Key('application-application-1')),
        findsOneWidget,
      );
      fail = false;
      await tapVisible(tester, find.text('Thử lại'));
      expect(
        find.byKey(const Key('application-application-2')),
        findsOneWidget,
      );
      expect(repository.applicationQueries, [
        (1, null),
        (1, 'REVIEWING'),
        (2, 'REVIEWING'),
        (2, 'REVIEWING'),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tap application opens fetched detail; withdrawal reloads status and list',
    (tester) async {
      await start(tester, tab: 2);
      await detail(tester);
      expect(repository.applicationDetailCalls, 1);
      expect(find.text('Chi tiết ứng tuyển'), findsOneWidget);
      expect(find.text('Đại học TIP'), findsOneWidget);
      expect(find.text('CV trong hồ sơ'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('withdrawApplication')));
      expect(find.textContaining('không thể nộp lại'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmWithdrawApplication')));
      await tester.pumpAndSettle();
      expect(repository.withdrawCalls, 1);
      expect(repository.applicationDetailCalls, 2);
      expect(find.byKey(const Key('withdrawApplication')), findsNothing);
      expect(find.text('Đã rút'), findsOneWidget);
      await tester.tap(find.byKey(const Key('applicationBack')));
      await tester.pumpAndSettle();
      expect(repository.applicationQueries, [(1, null), (1, null)]);
      expect(repository.summaryCalls, 2);
    },
  );

  testWidgets(
    'withdraw conflict reloads fresh terminal state without repeating PATCH',
    (tester) async {
      repository.onWithdraw = (_) async {
        repository.applicationStatus = 'ACCEPTED';
        throw const AuthFailure(FailureKind.conflict, 'Đơn đã thay đổi.');
      };
      await start(tester, tab: 2);
      await detail(tester);
      await tapVisible(tester, find.byKey(const Key('withdrawApplication')));
      await tester.tap(find.byKey(const Key('confirmWithdrawApplication')));
      await tester.pumpAndSettle();
      expect(repository.withdrawCalls, 1);
      expect(repository.applicationDetailCalls, 2);
      expect(find.text('Đơn đã thay đổi.'), findsOneWidget);
      expect(find.text('Được nhận'), findsOneWidget);
      expect(find.byKey(const Key('withdrawApplication')), findsNothing);
    },
  );

  for (final status in ['ACCEPTED', 'REJECTED', 'WITHDRAWN']) {
    testWidgets('terminal $status application has no withdraw control', (
      tester,
    ) async {
      repository.applicationStatus = status;
      await start(tester, tab: 2);
      await detail(tester);
      expect(find.byKey(const Key('withdrawApplication')), findsNothing);
      expect(repository.withdrawCalls, 0);
    });
  }

  testWidgets(
    'detail read failure offers retry without exposing stale personal data',
    (tester) async {
      repository.onApplication = (_) async =>
          throw const AuthFailure(FailureKind.server, 'Không tìm thấy đơn.');
      await start(tester, tab: 2);
      await detail(tester);
      expect(find.text('Không tìm thấy đơn.'), findsOneWidget);
      expect(find.text('Thông tin chi tiết đơn'), findsNothing);
      expect(find.byKey(const Key('withdrawApplication')), findsNothing);
      repository.onApplication = null;
      await tapVisible(tester, find.text('Tải lại đơn'));
      expect(find.text('Thông tin chi tiết đơn'), findsOneWidget);
      expect(repository.applicationDetailCalls, 2);
    },
  );

  testWidgets('detail opens original opportunity with reapplication disabled', (
    tester,
  ) async {
    await start(tester, tab: 2);
    await detail(tester);
    await tapVisible(tester, find.byKey(const Key('applicationOpportunity')));
    expect(
      find.text('Bạn đã có đơn ứng tuyển cho cơ hội này.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('applyOpportunity')))
          .onPressed,
      isNull,
    );
    expect(repository.applyCalls, 0);
  });

  testWidgets('confirmation and detail support 320px and enlarged text', (
    tester,
  ) async {
    await start(tester, size: const Size(320, 720), textScale: 1.5);
    await confirmation(tester);
    await consent(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opportunityBack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav2')));
    await tester.pumpAndSettle();
    await detail(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('withdrawApplication')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('application design previews', (tester) async {
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
    repository.onProfile = (_) async => StudentProfileModel.profile({
      ...profileFixture(),
      'cvUrl': 'https://example.com/cv.pdf',
    });
    repository.onFilteredApplications = (page, status) async => PageSlice(
      items: [
        for (final (index, state, title) in [
          (1, 'REVIEWING', 'Android Developer Intern'),
          (2, 'ACCEPTED', 'Frontend Web Developer'),
          (3, 'PENDING', 'AI & Data Analytics Intern'),
        ])
          ApplicationModel.application({
            ...applicationDetailFixture(status: state),
            'id': 'application-$index',
            'opportunity': {
              ...applicationDetailFixture()['opportunity']
                  as Map<String, Object?>,
              'title': title,
            },
          }),
      ],
      total: 3,
      page: page,
      limit: 20,
    );
    await start(tester, size: const Size(390, 1080));
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('applicationPreview')),
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

    await confirmation(tester);
    await capture('application_confirmation');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opportunityBack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav2')));
    await tester.pumpAndSettle();
    await capture('applications');
    await detail(tester);
    await capture('application_detail');
    await tapVisible(tester, find.byKey(const Key('withdrawApplication')));
    await capture('application_withdrawal');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending withdrawal blocks duplicate confirmation and PATCH', (
    tester,
  ) async {
    final pending = Completer<ApplicationDetail>();
    repository.onWithdraw = (_) => pending.future;
    await start(tester, tab: 2);
    await detail(tester);
    final withdraw = find.byKey(const Key('withdrawApplication'));
    await tester.ensureVisible(withdraw);
    await tester.pumpAndSettle();
    await tester.tap(withdraw);
    await tester.tap(withdraw, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmWithdrawApplication')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmWithdrawApplication')));
    await tester.pump();
    expect(repository.withdrawCalls, 1);
    expect(tester.widget<OutlinedButton>(withdraw).onPressed, isNull);
    repository.applicationStatus = 'WITHDRAWN';
    pending.complete(
      ApplicationModel.applicationDetail(
        applicationDetailFixture(status: 'WITHDRAWN'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.withdrawCalls, 1);
    expect(find.byKey(const Key('withdrawApplication')), findsNothing);
  });

  testWidgets(
    'withdraw sheet shows the selected application and dismissing never changes it',
    (tester) async {
      await start(tester, tab: 2);
      await detail(tester);
      final withdraw = find.byKey(const Key('withdrawApplication'));
      for (final dismissal in ['keep', 'back', 'outside']) {
        await tapVisible(tester, withdraw);
        expect(find.byType(ApplicationWithdrawalSheet), findsOneWidget);
        final sheet = tester.widget<ApplicationWithdrawalSheet>(
          find.byType(ApplicationWithdrawalSheet),
        );
        expect(sheet.title, 'Android Developer Intern');
        expect(sheet.company, 'ABC Technology');
        expect(repository.withdrawCalls, 0);
        if (dismissal == 'keep') {
          await tester.tap(find.byKey(const Key('keepApplication')));
        } else if (dismissal == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(8, 8));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ApplicationWithdrawalSheet), findsNothing);
        expect(find.text('Chi tiết ứng tuyển'), findsOneWidget);
        expect(repository.withdrawCalls, 0);
      }
    },
  );

  testWidgets(
    'withdraw sheet supports long content and enlarged text on a narrow screen',
    (tester) async {
      final data = applicationDetailFixture();
      data['opportunity'] = {
        ...data['opportunity'] as Map<String, Object?>,
        'title':
            'Android Developer Intern — Kotlin, Jetpack Compose và phát triển ứng dụng di động',
        'company': {
          'name': 'Công ty Công nghệ và Giải pháp Phần mềm ABC Technology',
          'status': 'VERIFIED',
        },
      };
      repository.onApplication = (_) async =>
          ApplicationModel.applicationDetail(data);
      await start(tester, tab: 2, size: const Size(320, 640), textScale: 2);
      await detail(tester);
      await tapVisible(tester, find.byKey(const Key('withdrawApplication')));
      await tapVisible(tester, find.byKey(const Key('keepApplication')));
      expect(repository.withdrawCalls, 0);
      expect(find.byType(ApplicationWithdrawalSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'withdraw timeout reads current state without retrying the mutation',
    (tester) async {
      repository.onWithdraw = (_) async {
        repository.applicationStatus = 'WITHDRAWN';
        throw const AuthFailure(
          FailureKind.timeout,
          'Chưa xác nhận được kết quả rút đơn.',
        );
      };
      await start(tester, tab: 2);
      await detail(tester);
      await tapVisible(tester, find.byKey(const Key('withdrawApplication')));
      await tester.tap(find.byKey(const Key('confirmWithdrawApplication')));
      await tester.pumpAndSettle();
      expect(repository.withdrawCalls, 1);
      expect(repository.applicationDetailCalls, 2);
      expect(find.text('Đã rút'), findsOneWidget);
      expect(find.byKey(const Key('withdrawApplication')), findsNothing);
      expect(
        find.text('Đã rút đơn ứng tuyển.'),
        findsNothing,
      ); // No success toast without a successful response.
    },
  );

  testWidgets(
    'unsafe CV scheme is not opened and URL is not included in the error',
    (tester) async {
      final data = applicationDetailFixture();
      data['student'] = {
        ...data['student'] as Map<String, Object?>,
        'cvUrl': 'javascript:secret-token',
      };
      repository.onApplication = (_) async =>
          ApplicationModel.applicationDetail(data);
      await start(tester, tab: 2);
      await detail(tester);
      await tapVisible(tester, find.byKey(const Key('viewApplicationCv')));
      expect(
        find.text('Chưa thể mở CV. Vui lòng kiểm tra liên kết trong hồ sơ.'),
        findsOneWidget,
      );
      expect(find.textContaining('secret-token'), findsNothing);
    },
  );
}
