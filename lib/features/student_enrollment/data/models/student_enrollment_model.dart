import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

abstract final class StudentEnrollmentModel {
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid enrollment data');
    }
    return value;
  }

  static String text(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $key');
    }
    return value;
  }

  static String? optionalText(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null || value == '') return null;
    if (value is! String) throw FormatException('Invalid $key');
    return value;
  }

  static List<dynamic> list(Object? value) {
    if (value is List) return value;
    throw const FormatException('Invalid enrollment list');
  }

  static EnrollmentSchool school(Object? value) {
    final data = object(value);
    if (data.containsKey('status') && data['status'] != 'VERIFIED') {
      throw const FormatException('Unverified enrollment university');
    }
    return EnrollmentSchool(
      id: text(data, 'id'),
      name: text(data, 'name'),
      code: optionalText(data, 'code'),
    );
  }

  static EnrollmentMajor major(Object? value, {String? universityId}) {
    final data = object(value);
    if (universityId != null &&
        data.containsKey('universityId') &&
        data['universityId'] != universityId) {
      throw const FormatException('Major belongs to another university');
    }
    return EnrollmentMajor(id: text(data, 'id'), name: text(data, 'name'));
  }

  static StudentEnrollment enrollment(Object? value) {
    final data = object(value);
    final semester = data['semester'];
    if (semester is! int || semester < 1 || semester > 8) {
      throw const FormatException('Invalid semester');
    }
    final status = text(data, 'status');
    if (!{'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'}.contains(status)) {
      throw const FormatException('Invalid enrollment status');
    }
    String? related(String relation, String field) => data[relation] == null
        ? null
        : optionalText(object(data[relation]), field);
    return StudentEnrollment(
      id: text(data, 'id'),
      universityId: text(data, 'universityId'),
      majorId: text(data, 'majorId'),
      studentCode: text(data, 'studentCode'),
      className: text(data, 'className'),
      semester: semester,
      status: status,
      universityName: related('university', 'name'),
      majorName: related('major', 'name'),
      reason: optionalText(data, 'reason'),
      createdAt: data['createdAt'] == null
          ? null
          : DateTime.parse(text(data, 'createdAt')),
      fullName: related('account', 'fullName'),
      email: related('account', 'email'),
    );
  }

  static EnrollmentQueue queue(Object? value) {
    final data = object(value);
    final total = data['total'], page = data['page'], limit = data['limit'];
    if (total is! int ||
        total < 0 ||
        page is! int ||
        page < 1 ||
        limit is! int ||
        limit < 1) {
      throw const FormatException('Invalid enrollment pagination');
    }
    return EnrollmentQueue(
      items: List.unmodifiable(list(data['data']).map(enrollment)),
      total: total,
      page: page,
      limit: limit,
    );
  }
}
