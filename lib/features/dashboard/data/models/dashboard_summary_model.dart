import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/features/dashboard/domain/entities/dashboard_summary.dart';

abstract final class DashboardSummaryModel {
  static DashboardSummary create({
    required StudentProfile profile,
    required PageSlice<ApplicationOverview> recent,
    required int reviewing,
    required int accepted,
    required PlacementOverview? placement,
  }) => DashboardSummary(
    profile: profile,
    applications: recent.items,
    submitted: recent.total,
    reviewing: reviewing,
    accepted: accepted,
    placement: placement,
  );
}
