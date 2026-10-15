import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/app.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';
import 'support/notification_fakes.dart';

void main() {
  late FakeNotificationsRepository notifications;
  late FakeAuthRemote remote;
  late AppDependencies dependencies;
  setUp(() {
    notifications = FakeNotificationsRepository()..items = [notification()];
    remote = FakeAuthRemote();
    final repositories = FakeDashboardRepository();
    dependencies = AppDependencies.create(
      notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      authRemote: remote,
      sessionStorage: MemorySessionStorage()..value = testCredential,
      dashboardRepository: repositories,
      opportunityRepository: repositories,
      applicationRepository: repositories,
      internshipRepository: repositories,
      studentProfileRepository: repositories,
      notificationsRepository: notifications,
    );
  });
  tearDown(() => dependencies.dispose());
  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('openNotifications')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'bell opens notifications, marks a row read and updates the header badge',
    (tester) async {
      await start(tester);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('notificationBadge')))
            .isLabelVisible,
        true,
      );
      await open(tester);
      expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
      expect(find.text('1 thông báo chưa đọc'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('readNotification-$notificationId')),
      );
      await tester.pumpAndSettle();
      expect(notifications.readCalls, 1);
      expect(find.text('0 thông báo chưa đọc'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('notificationBadge')))
            .isLabelVisible,
        false,
      );
    },
  );

  testWidgets('account without Student uses notifications and read-all', (
    tester,
  ) async {
    remote.onCurrentUser = () async => nonStudentUser;
    await start(tester);
    await open(tester);
    await tester.tap(find.byKey(const Key('readAllNotifications')));
    await tester.pumpAndSettle();
    expect(notifications.readAllCalls, 1);
    await tester.tap(find.byKey(const Key('notificationFilter-unread')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã đọc tất cả thông báo.'), findsOneWidget);
  });

  testWidgets(
    'list errors show retry without losing the authenticated session',
    (tester) async {
      notifications.onList = (_, page, limit) async => throw const AuthFailure(
        FailureKind.network,
        'Chưa thể tải thông báo.',
      );
      await start(tester);
      await open(tester);
      expect(find.text('Chưa thể tải thông báo.'), findsOneWidget);
      notifications.onList = null;
      await tester.tap(find.byKey(const Key('retryNotifications')));
      await tester.pumpAndSettle();
      expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
      expect(find.byKey(const Key('loginIdentifier')), findsNothing);
    },
  );

  testWidgets('logout removes the open notifications route and its state', (
    tester,
  ) async {
    await start(tester);
    await open(tester);
    remote.onCurrentUser = () async => throw const AuthFailure(
      FailureKind.sessionExpired,
      'Phiên đã hết hạn.',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Cập nhật của bạn'), findsNothing);
    expect(find.byKey(const Key('loginIdentifier')), findsOneWidget);
  });

  testWidgets(
    'small screen with enlarged text opens and reads full notification content',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      notifications.items = [
        notification(
          title: 'Cập nhật thông tin hồ sơ và trạng thái thực tập của bạn',
          body: 'Nội dung thông báo dài. ' * 30,
        ),
      ];
      await start(tester);
      await open(tester);
      final card = find.byKey(const Key('notification-$notificationId'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(notifications.readCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
