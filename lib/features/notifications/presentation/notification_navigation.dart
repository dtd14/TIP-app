import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/presentation/main_shell_controller.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/applications/domain/usecases/get_application.dart';
import 'package:tip_app/features/applications/presentation/pages/application_detail_page.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_placement_detail_page.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_period_detail_page.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/profile/domain/usecases/get_student_profile.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/presentation/pages/student_enrollment_page.dart';
import 'package:tip_app/features/student_enrollment/presentation/pages/enrollment_review_page.dart';
import '../domain/entities/app_notification.dart';
import '../domain/usecases/resolve_notification_destination.dart';

class NotificationNavigation {
  bool _opening = false;
  bool canOpen(BuildContext context, AppNotification item) {
    final user = context.read<AuthBloc>().state.user;
    return user != null &&
        const ResolveNotificationDestination()(item, user) != null;
  }

  Future<void> open(BuildContext context, AppNotification item) async {
    if (_opening) return;
    final auth = context.read<AuthBloc>();
    final user = auth.state.user;
    if (user == null) return;
    final destination = const ResolveNotificationDestination()(item, user);
    if (destination == null) return;
    final shell = context.read<MainShellController>();
    void restricted(AuthFailure failure) {
      if (context.mounted) auth.add(AuthAccessRestricted(failure));
    }

    _opening = true;
    try {
      final Widget page;
      switch (destination) {
        case NotificationDestination.accountProfile:
          shell.navigate(4);
          Navigator.of(context).popUntil((route) => route.isFirst);
          auth.add(const AuthRestoreRequested(preserveNavigation: true));
          return;
        case NotificationDestination.application:
          final repository = context.read<ApplicationRepository>();
          final detail = await GetApplication(repository)(item.entityId, user);
          page = ApplicationDetailPage(
            application: detail.application,
            user: user,
            repository: repository,
            onRestricted: restricted,
            onChanged: shell.refreshDashboard,
          );
        case NotificationDestination.placement:
          page = InternshipPlacementDetailPage(
            placementId: item.entityId,
            user: user,
            repository: context.read<InternshipRepository>(),
            onRestricted: restricted,
            onViewOpportunities: () => shell.navigate(1),
            onViewApplications: () => shell.navigate(2),
            onChanged: shell.refreshDashboard,
          );
        case NotificationDestination.internshipPeriod:
          final repository = context.read<InternshipRepository>();
          final profile = await GetStudentProfile(
            context.read<StudentProfileRepository>(),
          )(user);
          final registration = profile.internships
              .where((registration) => registration.periodId == item.entityId)
              .firstOrNull;
          if (registration == null) {
            throw const AuthFailure(
              FailureKind.validation,
              'Đợt thực tập không còn trong hồ sơ của bạn. Vui lòng tải lại.',
            );
          }
          page = InternshipPeriodDetailPage(
            registrationId: registration.id,
            user: user,
            repository: repository,
            onRestricted: restricted,
            onViewOpportunities: () => shell.navigate(1),
            onViewApplications: () => shell.navigate(2),
            onChanged: shell.refreshDashboard,
          );
        case NotificationDestination.enrollment:
          page = StudentEnrollmentPage(
            user: user,
            repository: context.read<StudentEnrollmentRepository>(),
            onRestricted: restricted,
            onReloadAccount: () =>
                auth.add(const AuthRestoreRequested(preserveNavigation: true)),
          );
        case NotificationDestination.enrollmentReview:
          page = EnrollmentReviewPage(
            user: user,
            repository: context.read<StudentEnrollmentRepository>(),
            onRestricted: restricted,
          );
      }
      if (!context.mounted) return;
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => page));
    } on Object catch (error) {
      if (!context.mounted) return;
      final failure = error is AuthFailure
          ? error
          : const AuthFailure(
              FailureKind.unexpected,
              'Chưa thể mở nội dung liên quan. Vui lòng thử lại.',
            );
      if (failure.kind == FailureKind.inactiveAccount) {
        restricted(failure);
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Chưa thể mở nội dung'),
            content: Text(failure.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } finally {
      _opening = false;
    }
  }
}
