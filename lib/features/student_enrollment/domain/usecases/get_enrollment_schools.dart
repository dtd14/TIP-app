import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class GetEnrollmentSchools {
  const GetEnrollmentSchools(this.repository);
  final StudentEnrollmentRepository repository;
  Future<List<EnrollmentSchool>> call({String keyword = ''}) =>
      repository.universities(keyword: keyword);
}
