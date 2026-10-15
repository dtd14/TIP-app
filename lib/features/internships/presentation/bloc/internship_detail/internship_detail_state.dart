import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';

class InternshipDetailState {
  const InternshipDetailState({
    required this.registration,
    required this.placements,
    required this.page,
    required this.failure,
    required this.placementFailure,
    required this.loading,
    required this.placementsLoading,
    required this.retryReset,
  });
  final InternshipRegistration? registration;
  final List<InternshipPlacement> placements;
  final PageSlice<InternshipPlacement>? page;
  final AuthFailure? failure;
  final AuthFailure? placementFailure;
  final bool loading;
  final bool placementsLoading;
  final bool retryReset;
}
