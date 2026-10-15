import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';

class GetPlacement {
  const GetPlacement(this.repository);
  final InternshipRepository repository;
  Future<InternshipPlacement> call(String id, AuthUser user) =>
      repository.getPlacement(id, user);
}
