import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';

class GetInternshipRegistration {
  const GetInternshipRegistration(this.repository);
  final InternshipRepository repository;
  Future<InternshipRegistration> call(String id, AuthUser user) =>
      repository.getInternshipRegistration(id, user);
}
