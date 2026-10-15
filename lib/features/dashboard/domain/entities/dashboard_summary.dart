import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.profile,
    required this.applications,
    required this.submitted,
    required this.reviewing,
    required this.accepted,
    this.placement,
  });
  final StudentProfile profile;
  final List<ApplicationOverview> applications;
  final int submitted, reviewing, accepted;
  final PlacementOverview? placement;
}
