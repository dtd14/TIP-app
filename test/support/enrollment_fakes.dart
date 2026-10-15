import 'dashboard_fixtures.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'dart:async';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';

const schoolAdmin = AuthUser(
  id: 'admin-1',
  fullName: 'Quản trị trường',
  accountStatus: 'ACTIVE',
  studentAccessGranted: false,
  globalRole: 'USER',
  emailVerified: true,
  hasSchoolProfile: true,
  schoolRole: 'UNIVERSITY_ADMIN',
  schoolStatus: 'ACTIVE',
);
const enrollmentInput = StudentEnrollmentInput(
  universityId: 'school-1',
  majorId: 'major-1',
  studentCode: 'SV001',
  className: 'CNTT01',
  semester: 4,
);
StudentEnrollment enrollment({
  String id = 'request-1',
  String status = 'PENDING',
}) => StudentEnrollment(
  id: id,
  universityId: 'school-1',
  majorId: 'major-1',
  studentCode: 'SV001',
  className: 'CNTT01',
  semester: 4,
  status: status,
  universityName: 'Đại học TIP',
  majorName: 'Công nghệ thông tin',
  fullName: 'Nguyễn Văn An',
  email: 'student@example.com',
  reason: status == 'REJECTED' ? 'Mã sinh viên chưa đúng' : null,
);

class FakeEnrollmentRepository implements StudentEnrollmentRepository {
  List<StudentEnrollment> items = [];
  int mineCalls = 0, submitCalls = 0, cancelCalls = 0, reviewCalls = 0;
  StudentEnrollmentInput? submitted;
  String? reviewedId, reviewedReason;
  bool? approved;
  Future<List<StudentEnrollment>> Function()? onMine;
  Future<void> Function()? onSubmit, onCancel, onReview;
  Future<List<EnrollmentSchool>> Function(String)? onUniversities;
  Future<List<EnrollmentMajor>> Function(String)? onMajors;
  Future<EnrollmentQueue> Function(String?, String, int)? onQueue;
  @override
  Future<List<EnrollmentSchool>> universities({String keyword = ''}) async =>
      onUniversities != null
      ? onUniversities!(keyword)
      : const [
          EnrollmentSchool(id: 'school-1', name: 'Đại học TIP', code: 'TIP'),
          EnrollmentSchool(id: 'school-2', name: 'Đại học khác'),
        ];
  @override
  Future<List<EnrollmentMajor>> majors(String universityId) async =>
      onMajors != null
      ? onMajors!(universityId)
      : [
          EnrollmentMajor(
            id: 'major-$universityId',
            name: 'Công nghệ thông tin',
          ),
        ];
  @override
  Future<List<StudentEnrollment>> mine() async {
    mineCalls++;
    return onMine != null ? onMine!() : List.of(items);
  }

  @override
  Future<void> submit(StudentEnrollmentInput input) async {
    submitCalls++;
    submitted = input;
    if (onSubmit != null) {
      await onSubmit!();
    } else {
      items = [enrollment(id: 'request-${items.length + 1}'), ...items];
    }
  }

  @override
  Future<void> cancel(String id) async {
    cancelCalls++;
    if (onCancel != null) {
      await onCancel!();
    } else {
      items = items
          .map((e) => e.id == id ? enrollment(id: id, status: 'CANCELLED') : e)
          .toList();
    }
  }

  @override
  Future<EnrollmentQueue> queue({
    String? status,
    String keyword = '',
    int page = 1,
  }) async => onQueue != null
      ? onQueue!(status, keyword, page)
      : EnrollmentQueue(
          items: items
              .where((e) => status == null || e.status == status)
              .toList(),
          total: items.length,
          page: page,
          limit: 20,
        );
  @override
  Future<void> review(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    reviewCalls++;
    reviewedId = id;
    reviewedReason = reason;
    approved = approve;
    if (onReview != null) {
      await onReview!();
    } else {
      items = [];
    }
  }
}

class FakeStudentProfileRepository implements StudentProfileRepository {
  Future<StudentProfile> Function(AuthUser)? onProfile;
  @override
  Future<StudentProfile> getStudentProfile(AuthUser user) async =>
      onProfile == null ? dashboardFixture().profile : onProfile!(user);
  int calls = 0;
  String? name, phone;
  CvUpload? cv;
  Future<void> Function()? onUpdate;
  @override
  Future<void> update({String? fullName, String? phone, CvUpload? cv}) async {
    calls++;
    name = fullName;
    this.phone = phone;
    this.cv = cv;
    await onUpdate?.call();
  }
}
