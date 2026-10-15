import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';

class CancelEnrollment {
  const CancelEnrollment(this.repository);
  final StudentEnrollmentRepository repository;
  Future<void> call(String id) => repository.cancel(id);
}
