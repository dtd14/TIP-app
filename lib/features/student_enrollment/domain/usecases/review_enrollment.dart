import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';

class ReviewEnrollment {
  const ReviewEnrollment(this.repository);
  final StudentEnrollmentRepository repository;
  Future<void> call(String id, {required bool approve, String? reason}) =>
      repository.review(id, approve: approve, reason: reason);
}
