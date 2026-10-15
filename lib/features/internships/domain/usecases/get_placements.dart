import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';

class GetPlacements {
  const GetPlacements(this.repository);
  final InternshipRepository repository;
  Future<PageSlice<InternshipPlacement>> call(
    AuthUser user, {
    int page = 1,
    String? registrationId,
  }) => repository.getPlacements(
    user,
    page: page,
    registrationId: registrationId,
  );
}
