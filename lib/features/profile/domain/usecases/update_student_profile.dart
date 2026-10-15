import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';

class UpdateStudentProfile {
  const UpdateStudentProfile(this.repository);
  final StudentProfileRepository repository;
  Future<void> call({String? fullName, String? phone, CvUpload? cv}) =>
      repository.update(fullName: fullName, phone: phone, cv: cv);
}
