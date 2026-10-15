import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class SubmitEnrollment {
  const SubmitEnrollment(this.repository);
  final StudentEnrollmentRepository repository;
  Future<void> call(StudentEnrollmentInput input) => repository.submit(input);
}
