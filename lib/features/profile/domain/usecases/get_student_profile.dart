import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';

class GetStudentProfile {
  const GetStudentProfile(this.repository);
  final StudentProfileRepository repository;
  Future<StudentProfile> call(AuthUser user) =>
      repository.getStudentProfile(user);
}
