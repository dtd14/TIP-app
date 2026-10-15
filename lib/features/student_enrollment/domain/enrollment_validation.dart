import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/validators.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

/// Matches CreateEnrollmentDto, ReviewEnrollmentDto and EnrollmentQueryDto.
abstract final class EnrollmentValidation {
  static String? studentCode(String? value) =>
      Validators.limitedText(value, 'mã sinh viên', 50);
  static String? className(String? value) =>
      Validators.limitedText(value, 'lớp', 100);
  static String? reason(String? value) =>
      Validators.limitedText(value, 'lý do từ chối', 500);
  static String? keyword(String value) => value.trim().runes.length > 100
      ? 'Từ khóa tìm kiếm tối đa 100 ký tự.'
      : null;

  static AuthFailure? input(StudentEnrollmentInput input) {
    final errors = <String, String>{
      'studentCode': ?studentCode(input.studentCode),
      'className': ?className(input.className),
      if (input.universityId.trim().isEmpty)
        'universityId': 'Vui lòng chọn trường đại học.',
      if (input.majorId.trim().isEmpty) 'majorId': 'Vui lòng chọn ngành học.',
      if (input.semester < 1 || input.semester > 8)
        'semester': 'Học kỳ phải từ 1 đến 8.',
    };
    return errors.isEmpty
        ? null
        : AuthFailure(
            FailureKind.validation,
            errors.values.first,
            fieldErrors: errors,
          );
  }
}
