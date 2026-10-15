import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';

abstract interface class StudentProfileRepository {
  Future<StudentProfile> getStudentProfile(AuthUser user);
  Future<void> update({String? fullName, String? phone, CvUpload? cv});
}
