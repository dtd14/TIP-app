import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/dashboard/data/models/dashboard_summary_model.dart';

/// Composes independently owned API repositories for the home-page preview.
class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(
    this.profiles,
    this.applications,
    this.internships,
  );
  final StudentProfileRepository profiles;
  final ApplicationRepository applications;
  final InternshipRepository internships;
  Future<DashboardSummary> summary(AuthUser user) async {
    final profile = await profiles.getStudentProfile(user);
    final results = await Future.wait<Object>([
      applications.getApplications(limit: 3),
      applications.getApplications(limit: 1, status: 'REVIEWING'),
      applications.getApplications(limit: 1, status: 'ACCEPTED'),
      internships.getPlacementPreview('IN_PROGRESS'),
      internships.getPlacementPreview('CONFIRMED'),
      internships.getPlacementPreview('PENDING'),
    ]);
    return DashboardSummaryModel.create(
      profile: profile,
      recent: results[0] as PageSlice<ApplicationOverview>,
      reviewing: (results[1] as PageSlice<ApplicationOverview>).total,
      accepted: (results[2] as PageSlice<ApplicationOverview>).total,
      placement: results
          .skip(3)
          .cast<PageSlice<PlacementOverview>>()
          .expand((page) => page.items)
          .firstOrNull,
    );
  }
}
