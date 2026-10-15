import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';

class ApplicationConfirmationState {
  const ApplicationConfirmationState({
    required this.profile,
    required this.opportunity,
    required this.failure,
    required this.loading,
    required this.sending,
    required this.consent,
    required this.uncertain,
    required this.submitted,
  });
  final StudentProfile? profile;
  final OpportunityOverview? opportunity;
  final AuthFailure? failure;
  final bool loading;
  final bool sending;
  final bool consent;
  final bool uncertain;
  final ApplicationOverview? submitted;
}
