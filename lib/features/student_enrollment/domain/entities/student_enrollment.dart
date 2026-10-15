class EnrollmentSchool {
  const EnrollmentSchool({required this.id, required this.name, this.code});
  final String id, name;
  final String? code;
}

class EnrollmentMajor {
  const EnrollmentMajor({required this.id, required this.name});
  final String id, name;
}

class StudentEnrollmentInput {
  const StudentEnrollmentInput({
    required this.universityId,
    required this.majorId,
    required this.studentCode,
    required this.className,
    required this.semester,
  });
  final String universityId, majorId, studentCode, className;
  final int semester;
}

class StudentEnrollment {
  const StudentEnrollment({
    required this.id,
    required this.universityId,
    required this.majorId,
    required this.studentCode,
    required this.className,
    required this.semester,
    required this.status,
    this.universityName,
    this.majorName,
    this.reason,
    this.createdAt,
    this.fullName,
    this.email,
  });
  final String id, universityId, majorId, studentCode, className, status;
  final int semester;
  final String? universityName, majorName, reason, fullName, email;
  final DateTime? createdAt;
  bool get isPending => status == 'PENDING';
  String get statusLabel => switch (status) {
    'PENDING' => 'Chờ xét duyệt',
    'APPROVED' => 'Đã được duyệt',
    'REJECTED' => 'Đã từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chưa xác định',
  };
}

class EnrollmentQueue {
  const EnrollmentQueue({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });
  final List<StudentEnrollment> items;
  final int total, page, limit;
  bool get hasNext => page * limit < total;
}
