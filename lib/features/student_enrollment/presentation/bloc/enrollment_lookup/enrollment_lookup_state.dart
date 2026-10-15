import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class EnrollmentLookupState {
  const EnrollmentLookupState({
    this.schools = const [],
    this.majors = const [],
    this.loadingSchools = false,
    this.loadingMajors = false,
    this.schoolFailure,
    this.majorFailure,
  });
  final List<EnrollmentSchool> schools;
  final List<EnrollmentMajor> majors;
  final bool loadingSchools, loadingMajors;
  final AuthFailure? schoolFailure, majorFailure;
}
