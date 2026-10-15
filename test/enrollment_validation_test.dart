import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/features/student_enrollment/domain/enrollment_validation.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

void main() {
  test(
    'CreateEnrollmentDto text limits apply after trim and count Unicode characters',
    () {
      expect(EnrollmentValidation.studentCode(' ${'é' * 50} '), isNull);
      expect(EnrollmentValidation.className(' ${'😀' * 100} '), isNull);
      expect(EnrollmentValidation.studentCode('s' * 51), contains('50'));
      expect(EnrollmentValidation.className('c' * 101), contains('100'));
      expect(EnrollmentValidation.studentCode(' '), isNotNull);
      expect(EnrollmentValidation.className(null), isNotNull);
    },
  );
  test(
    'required selection and semester boundaries match CreateEnrollmentDto',
    () {
      StudentEnrollmentInput input(int semester, {String school = 'school'}) =>
          StudentEnrollmentInput(
            universityId: school,
            majorId: 'major',
            studentCode: 'SV001',
            className: 'CNTT',
            semester: semester,
          );
      expect(EnrollmentValidation.input(input(1)), isNull);
      expect(EnrollmentValidation.input(input(8)), isNull);
      expect(
        EnrollmentValidation.input(input(0))?.fieldErrors,
        contains('semester'),
      );
      expect(
        EnrollmentValidation.input(input(9))?.fieldErrors,
        contains('semester'),
      );
      expect(
        EnrollmentValidation.input(input(1, school: ' '))?.fieldErrors,
        contains('universityId'),
      );
    },
  );
  test('review reason is required and limited to 500 trimmed characters', () {
    expect(EnrollmentValidation.reason(' '), isNotNull);
    expect(EnrollmentValidation.reason(' ${'r' * 500} '), isNull);
    expect(EnrollmentValidation.reason('r' * 501), contains('500'));
  });
}
