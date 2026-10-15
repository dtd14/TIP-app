import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import '../entities/app_notification.dart';

enum NotificationDestination {
  application,
  placement,
  internshipPeriod,
  enrollment,
  enrollmentReview,
  accountProfile,
}

class ResolveNotificationDestination {
  const ResolveNotificationDestination();
  NotificationDestination? call(AppNotification notification, AuthUser user) {
    if (!user.canAccessHome || notification.entityId.isEmpty) return null;
    return switch (notification.entityType) {
      'Application' when user.canAccessStudentApp =>
        NotificationDestination.application,
      'Placement' when user.canAccessStudentApp =>
        NotificationDestination.placement,
      'InternshipPeriod' when user.canAccessStudentApp =>
        NotificationDestination.internshipPeriod,
      'StudentEnrollment' when user.canViewStudentEnrollments =>
        NotificationDestination.enrollment,
      'StudentEnrollmentReview' when user.canReviewStudentEnrollments =>
        NotificationDestination.enrollmentReview,
      'AccountProfile' when notification.entityId == user.id =>
        NotificationDestination.accountProfile,
      _ => null,
    };
  }
}
