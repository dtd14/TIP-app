import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class GetEnrollmentQueue {
  const GetEnrollmentQueue(this.repository);
  final StudentEnrollmentRepository repository;
  Future<EnrollmentQueue> call({
    String? status,
    String keyword = '',
    int page = 1,
  }) => repository.queue(status: status, keyword: keyword, page: page);
}
