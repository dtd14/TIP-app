import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class GetEnrollmentMajors {
  const GetEnrollmentMajors(this.repository);
  final StudentEnrollmentRepository repository;
  Future<List<EnrollmentMajor>> call(String universityId) =>
      repository.majors(universityId);
}
