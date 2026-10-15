import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';

class InternshipListState {
  const InternshipListState({
    this.registrationFilter = 'ALL',
    this.visibleRegistrations = 20,
    required this.profile,
    required this.placements,
    required this.page,
    required this.failure,
    required this.placementFailure,
    required this.loading,
    required this.placementsLoading,
    required this.retryReset,
  });
  final String registrationFilter;
  final int visibleRegistrations;
  List<InternshipRegistration> get registrations => List.unmodifiable(
    [...?profile?.internships]
      ..sort((a, b) => b.startDate.compareTo(a.startDate)),
  );
  List<InternshipRegistration> get filteredRegistrations => List.unmodifiable(
    registrations.where(
      (item) =>
          registrationFilter == 'ALL' ||
          (registrationFilter == 'ACTIVE' ? item.isActive : item.isCompleted),
    ),
  );
  bool get hasMoreRegistrations =>
      filteredRegistrations.length > visibleRegistrations;
  final StudentProfile? profile;
  final List<InternshipPlacement> placements;
  final PageSlice<InternshipPlacement>? page;
  final AuthFailure? failure;
  final AuthFailure? placementFailure;
  final bool loading;
  final bool placementsLoading;
  final bool retryReset;
}
