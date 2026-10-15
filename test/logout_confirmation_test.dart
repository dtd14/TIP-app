import 'support/notification_fakes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/app.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';

void main() {
  late FakeAuthRemote remote;
  late MemorySessionStorage storage;
  late AppDependencies dependencies;

  setUp(() {
    remote = FakeAuthRemote();
    storage = MemorySessionStorage()..value = testCredential;
    final repositories = FakeDashboardRepository();
    dependencies = AppDependencies.create(
      notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      notificationsRepository: FakeNotificationsRepository(),
      authRemote: remote,
      sessionStorage: storage,
      dashboardRepository: repositories,
      opportunityRepository: repositories,
      applicationRepository: repositories,
      internshipRepository: repositories,
      studentProfileRepository: repositories,
    );
  });
  tearDown(() => dependencies.dispose());

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();
  }

  for (final entry in [
    'header',
    'drawer',
    'profile',
    'account',
    'restricted',
  ]) {
    testWidgets(
      '$entry logout requires confirmation; cancel keeps the session',
      (tester) async {
        if (entry == 'restricted') {
          remote.onCurrentUser = () async => const AuthUser(
            id: 'account-1',
            fullName: 'Nguyễn Văn An',
            accountStatus: 'SUSPENDED',
            studentAccessGranted: false,
          );
        } else if (entry == 'account') {
          remote.onCurrentUser = () async => nonStudentUser;
        }
        await start(tester);
        final Finder target;
        switch (entry) {
          case 'drawer':
            await tester.tap(find.byTooltip('Menu tài khoản'));
            await tester.pumpAndSettle();
            target = find.widgetWithText(ListTile, 'Đăng xuất');
          case 'profile':
            await tester.tap(find.byKey(const Key('nav4')));
            await tester.pumpAndSettle();
            target = find.byKey(const Key('profileLogout'));
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
          case 'account':
            await tester.tap(find.byKey(const Key('nav4')));
            await tester.pumpAndSettle();
            target = find.widgetWithText(OutlinedButton, 'Đăng xuất');
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
          case 'restricted':
            target = find.byKey(const Key('restrictedLogout'));
          default:
            target = find.byKey(const Key('logout'));
        }

        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('logoutConfirmation')), findsOneWidget);
        expect(remote.logoutCalls, 0);
        expect(storage.value, isNotNull);

        await tester.tap(find.byKey(const Key('cancelLogout')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('logoutConfirmation')), findsNothing);
        expect(remote.logoutCalls, 0);
        expect(storage.value, isNotNull);
        expect(find.byKey(const Key('loginIdentifier')), findsNothing);

        await tester.tap(target);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmLogout')));
        await tester.pumpAndSettle();
        expect(remote.logoutCalls, 1);
        expect(storage.value, isNull);
        expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('dismissing the confirmation also keeps the session', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logoutConfirmation')), findsNothing);
    expect(remote.logoutCalls, 0);
    expect(storage.value, isNotNull);

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logoutConfirmation')), findsNothing);
    expect(remote.logoutCalls, 0);
    expect(storage.value, isNotNull);
  });
}
