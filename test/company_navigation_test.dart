import 'support/notification_fakes.dart';
import 'package:tip_app/features/opportunities/data/models/opportunity_model.dart';
import 'package:tip_app/features/applications/data/models/application_model.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/app.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/internships/presentation/widgets/internship_ui.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';

void main() {
  late FakeAuthRemote remote;
  late FakeDashboardRepository repository;
  late AppDependencies dependencies;
  late List<String> companyIds;
  setUp(() {
    remote = FakeAuthRemote();
    repository = FakeDashboardRepository();
    companyIds = [];
    repository.onCompany = (id) async {
      companyIds.add(id);
      return OpportunityModel.company({...companyFixture, 'id': id});
    };
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
  Future<void> start(WidgetTester tester, int tab) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    if (tab != 0) {
      await tester.tap(find.byKey(Key('nav$tab')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final logo in [false, true]) {
    testWidgets(
      'internship ${logo ? 'logo' : 'company name'} opens company instead of placement',
      (tester) async {
        await start(tester, 3);
        final target = find.descendant(
          of: find.byType(InternshipPlacementTile),
          matching: logo
              ? find.byType(CompanyAvatar)
              : find.byType(CompanyName),
        );
        await tap(tester, target);
        expect(find.text('Doanh nghiệp'), findsOneWidget);
        expect(find.text('Chi tiết vị trí thực tập'), findsNothing);
        expect(repository.placementCalls, 0);
        expect(companyIds, ['company-1']);
        await tester.tap(find.byKey(const Key('companyBack')));
        await tester.pumpAndSettle();
        expect(find.text('Thực tập của tôi'), findsOneWidget);
      },
    );
  }

  for (final key in [
    'placementCompanyLogo',
    'placementCompanyName',
    'placementReceivingCompanyName',
  ]) {
    testWidgets('$key opens the placement company', (tester) async {
      await start(tester, 3);
      await tap(
        tester,
        find.byKey(const Key('internshipPlacement-placement-1')),
      );
      await tap(tester, find.byKey(Key(key)));
      expect(find.text('Doanh nghiệp'), findsOneWidget);
      expect(companyIds, ['company-1', 'company-1']);
      await tester.tap(find.byKey(const Key('companyBack')));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết vị trí thực tập'), findsOneWidget);
      expect(find.text('Xem doanh nghiệp'), findsNothing);
    });
  }

  for (final logo in [false, true]) {
    testWidgets(
      'public opportunity ${logo ? 'logo' : 'name'} resolves the protected company ID for a student',
      (tester) async {
        await start(tester, 1);
        await tap(
          tester,
          (logo ? find.byType(CompanyAvatar) : find.byType(CompanyName)).first,
        );
        expect(find.text('Doanh nghiệp'), findsOneWidget);
        expect(find.text('Chi tiết cơ hội'), findsNothing);
        expect(repository.detailCalls, 1);
        expect(companyIds, ['company-1']);
        expect(repository.applyCalls, 0);
      },
    );
  }

  testWidgets(
    'company lookup failure keeps the opportunity list with retry guidance',
    (tester) async {
      repository.onOpportunity = (_) async => throw const AuthFailure(
        FailureKind.network,
        'Chưa tải được doanh nghiệp.',
      );
      await start(tester, 1);
      await tap(tester, find.byType(CompanyAvatar).first);
      expect(find.text('Chưa tải được doanh nghiệp.'), findsOneWidget);
      expect(find.byKey(const Key('opportunitySearch')), findsOneWidget);
      expect(companyIds, isEmpty);
    },
  );

  testWidgets(
    'personal public account never guesses company identity from its name',
    (tester) async {
      remote.onCurrentUser = () async => nonStudentUser;
      await start(tester, 1);
      await tap(tester, find.byType(CompanyAvatar).first);
      expect(
        find.text('Chưa thể mở thông tin doanh nghiệp từ mục này.'),
        findsOneWidget,
      );
      expect(repository.detailCalls, 0);
      expect(companyIds, isEmpty);
    },
  );

  testWidgets(
    'personal account opens public company when company ID is supplied',
    (tester) async {
      remote.onCurrentUser = () async => nonStudentUser;
      repository.onOpportunities = (page) async => PageSlice(
        items: [OpportunityModel.publicOpportunity(opportunityDetailFixture)],
        total: 1,
        page: page,
        limit: 12,
      );
      await start(tester, 1);
      await tap(tester, find.byType(CompanyName).first);
      expect(find.text('Doanh nghiệp'), findsOneWidget);
      expect(companyIds, ['company-1']);
      expect(repository.detailCalls, 0);
      expect(repository.companyOpportunityCalls, 0);
    },
  );

  for (final logo in [false, true]) {
    testWidgets(
      'application ${logo ? 'logo' : 'name'} opens company without opening application detail',
      (tester) async {
        repository.onApplications = (page) async => PageSlice(
          items: [ApplicationModel.application(applicationDetailFixture())],
          total: 1,
          page: page,
          limit: 20,
        );
        await start(tester, 2);
        await tap(
          tester,
          (logo ? find.byType(CompanyAvatar) : find.byType(CompanyName)).first,
        );
        expect(find.text('Doanh nghiệp'), findsOneWidget);
        expect(find.text('Chi tiết ứng tuyển'), findsNothing);
        expect(repository.applicationDetailCalls, 0);
        expect(companyIds, ['company-1']);
      },
    );
  }

  testWidgets(
    'rapid taps wait for one company resolution and open only one page',
    (tester) async {
      final pending = Completer<OpportunityOverview>();
      repository.onOpportunity = (_) => pending.future;
      await start(tester, 1);
      final logo = find.byType(CompanyAvatar).first;
      await tester.tap(logo);
      await tester.tap(logo);
      await tester.pump();
      expect(repository.detailCalls, 1);
      pending.complete(OpportunityModel.opportunity(opportunityDetailFixture));
      await tester.pumpAndSettle();
      expect(companyIds, ['company-1']);
      await tester.tap(find.byKey(const Key('companyBack')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('opportunitySearch')), findsOneWidget);
    },
  );

  testWidgets('company link on opportunity detail uses the confirmed ID', (
    tester,
  ) async {
    await start(tester, 1);
    await tap(
      tester,
      find.byKey(const Key('opportunityDetails-opportunity-1')),
    );
    await tap(tester, find.byType(CompanyName).first);
    expect(find.text('Doanh nghiệp'), findsOneWidget);
    expect(repository.detailCalls, 1);
    await tester.tap(find.byKey(const Key('companyBack')));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết cơ hội'), findsOneWidget);
  });
}
