import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';
import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';

abstract interface class InternshipRepository {
  Future<PageSlice<PlacementOverview>> getPlacementPreview(String status);
  Future<InternshipRegistration> getInternshipRegistration(
    String id,
    AuthUser user,
  );
  Future<PageSlice<InternshipPlacement>> getPlacements(
    AuthUser user, {
    int page = 1,
    String? registrationId,
  });
  Future<InternshipPlacement> getPlacement(String id, AuthUser user);
}
