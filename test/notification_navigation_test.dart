import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/app.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_period_detail_page.dart';
import 'package:tip_app/features/applications/presentation/pages/application_detail_page.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_placement_detail_page.dart';
import 'package:tip_app/features/student_enrollment/presentation/pages/student_enrollment_page.dart';
import 'package:tip_app/features/student_enrollment/presentation/pages/enrollment_review_page.dart';
import 'notification_destination_test.dart' show relatedNotification;
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';
import 'support/enrollment_fakes.dart';
import 'support/notification_fakes.dart';

void main() {
  testWidgets(
    'profile approval checks auth/me and keeps the profile tab after Student permissions change',
    (tester) async {
      final remote = FakeAuthRemote();
      remote.onCurrentUser = () async => remote.currentUserCalls == 1
          ? AuthUser(
              id: studentUser.id,
              fullName: studentUser.fullName,
              accountStatus: 'ACTIVE',
              studentAccessGranted: false,
              globalRole: 'USER',
              emailVerified: true,
            )
          : studentUser;
      final repositories = FakeDashboardRepository();
      final dependencies = AppDependencies.create(
        authRemote: remote,
        sessionStorage: MemorySessionStorage()..value = testCredential,
        dashboardRepository: repositories,
        opportunityRepository: repositories,
        applicationRepository: repositories,
        internshipRepository: repositories,
        studentProfileRepository: repositories,
        notificationsRepository: FakeNotificationsRepository()
          ..items = [relatedNotification('AccountProfile', studentUser.id)],
        notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nav2')), findsNothing);
      await tester.tap(find.byKey(const Key('openNotifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notification-notification-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openNotificationRelated')));
      await tester.pumpAndSettle();
      expect(remote.currentUserCalls, 2);
      expect(find.byKey(const Key('nav2')), findsOneWidget);
      expect(find.text('Hồ sơ sinh viên'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final type in [
    'Application',
    'Placement',
    'InternshipPeriod',
    'StudentEnrollment',
    'StudentEnrollmentReview',
    'AccountProfile',
  ]) {
    testWidgets('$type opens an authorized existing screen', (tester) async {
      final remote = FakeAuthRemote();
      if (type == 'StudentEnrollmentReview') {
        remote.onCurrentUser = () async => schoolAdmin;
      }
      final repositories = FakeDashboardRepository();
      final notifications = FakeNotificationsRepository();
      final id = switch (type) {
        'Application' => 'application-1',
        'Placement' => 'placement-1',
        'InternshipPeriod' => 'period-1',
        'AccountProfile' => studentUser.id,
        _ => 'request-1',
      };
      notifications.items = [relatedNotification(type, id)];
      String? registrationId;
      repositories.onRegistration = (id) async {
        registrationId = id;
        return dashboardFixture().profile.internships.single;
      };
      final dependencies = AppDependencies.create(
        authRemote: remote,
        sessionStorage: MemorySessionStorage()..value = testCredential,
        dashboardRepository: repositories,
        opportunityRepository: repositories,
        applicationRepository: repositories,
        internshipRepository: repositories,
        studentProfileRepository: repositories,
        studentEnrollmentRepository: FakeEnrollmentRepository(),
        notificationsRepository: notifications,
        notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openNotifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notification-notification-1')));
      await tester.pumpAndSettle();
      final related = find.byKey(const Key('openNotificationRelated'));
      await tester.ensureVisible(related);
      await tester.pumpAndSettle();
      await tester.tap(related);
      await tester.pumpAndSettle();
      switch (type) {
        case 'Application':
          expect(find.byType(ApplicationDetailPage), findsOneWidget);
        case 'Placement':
          expect(find.byType(InternshipPlacementDetailPage), findsOneWidget);
        case 'InternshipPeriod':
          expect(find.byType(InternshipPeriodDetailPage), findsOneWidget);
          expect(registrationId, 'registration-1');
        case 'StudentEnrollment':
          expect(find.byType(StudentEnrollmentPage), findsOneWidget);
        case 'StudentEnrollmentReview':
          expect(find.byType(EnrollmentReviewPage), findsOneWidget);
        case 'AccountProfile':
          expect(find.text('Hồ sơ sinh viên'), findsOneWidget);
          expect(
            find.byKey(const Key('openNotificationRelated')),
            findsNothing,
          );
          expect(remote.currentUserCalls, 2);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a period outside the student profile shows an error without inventing a registration ID',
    (tester) async {
      final repositories = FakeDashboardRepository();
      final dependencies = AppDependencies.create(
        authRemote: FakeAuthRemote(),
        sessionStorage: MemorySessionStorage()..value = testCredential,
        dashboardRepository: repositories,
        opportunityRepository: repositories,
        applicationRepository: repositories,
        internshipRepository: repositories,
        studentProfileRepository: repositories,
        notificationsRepository: FakeNotificationsRepository()
          ..items = [relatedNotification('InternshipPeriod', 'not-owned')],
        notificationRealtimeRepository: FakeNotificationRealtimeRepository(),
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openNotifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notification-notification-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openNotificationRelated')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Đợt thực tập không còn trong hồ sơ'),
        findsOneWidget,
      );
      expect(find.byType(InternshipPeriodDetailPage), findsNothing);
      expect(repositories.registrationCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
