import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class GetMyEnrollments {
  const GetMyEnrollments(this.repository);
  final StudentEnrollmentRepository repository;
  Future<List<StudentEnrollment>> call() => repository.mine();
}
