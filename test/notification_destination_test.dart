import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/features/notifications/domain/entities/app_notification.dart';
import 'package:tip_app/features/notifications/domain/usecases/resolve_notification_destination.dart';
import 'support/auth_fakes.dart';
import 'support/enrollment_fakes.dart' show schoolAdmin;

AppNotification relatedNotification(String type, String id) => AppNotification(
  id: 'notification-1',
  type: 'UPDATED',
  title: 'Cập nhật',
  body: 'Thông tin đã thay đổi.',
  entityType: type,
  entityId: id,
  createdAt: DateTime.utc(2026, 10, 8),
  readAt: null,
);

void main() {
  const resolve = ResolveNotificationDestination();
  test('student links use exact backend entity types', () {
    expect(
      resolve(relatedNotification('Application', 'application-1'), studentUser),
      NotificationDestination.application,
    );
    expect(
      resolve(relatedNotification('Placement', 'placement-1'), studentUser),
      NotificationDestination.placement,
    );
    expect(
      resolve(relatedNotification('InternshipPeriod', 'period-1'), studentUser),
      NotificationDestination.internshipPeriod,
    );
    expect(
      resolve(
        relatedNotification('StudentEnrollment', 'request-1'),
        nonStudentUser,
      ),
      NotificationDestination.enrollment,
    );
  });
  test('current permissions gate student and school-review routes', () {
    expect(
      resolve(
        relatedNotification('Application', 'application-1'),
        nonStudentUser,
      ),
      isNull,
    );
    expect(
      resolve(relatedNotification('Placement', 'placement-1'), schoolAdmin),
      isNull,
    );
    expect(
      resolve(
        relatedNotification('StudentEnrollmentReview', 'request-1'),
        studentUser,
      ),
      isNull,
    );
    expect(
      resolve(
        relatedNotification('StudentEnrollmentReview', 'request-1'),
        schoolAdmin,
      ),
      NotificationDestination.enrollmentReview,
    );
  });
  test(
    'profile links target own account; unsupported admin entities remain content only',
    () {
      expect(
        resolve(
          relatedNotification('AccountProfile', studentUser.id),
          studentUser,
        ),
        NotificationDestination.accountProfile,
      );
      expect(
        resolve(
          relatedNotification('AccountProfile', 'other-account'),
          studentUser,
        ),
        isNull,
      );
      for (final type in [
        'SchoolUser',
        'CompanyUser',
        'UniversityRegistration',
        'Unknown',
      ]) {
        expect(
          resolve(relatedNotification(type, 'record-1'), schoolAdmin),
          isNull,
        );
      }
    },
  );
}
