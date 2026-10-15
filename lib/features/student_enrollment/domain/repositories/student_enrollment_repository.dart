import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

abstract interface class StudentEnrollmentRepository {
  Future<List<EnrollmentSchool>> universities({String keyword = ''});
  Future<List<EnrollmentMajor>> majors(String universityId);
  Future<List<StudentEnrollment>> mine();
  Future<void> submit(StudentEnrollmentInput input);
  Future<void> cancel(String id);
  Future<EnrollmentQueue> queue({
    String? status,
    String keyword = '',
    int page = 1,
  });
  Future<void> review(String id, {required bool approve, String? reason});
}
