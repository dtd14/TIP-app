import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';

class StudentCvState {
  const StudentCvState({
    this.uploadSucceeded = false,
    required this.profile,
    required this.failure,
    required this.selected,
    required this.loading,
    required this.picking,
    required this.uploading,
    required this.trusted,
    required this.changed,
    required this.uncertain,
  });
  final StudentProfile? profile;
  final AuthFailure? failure;
  final CvUpload? selected;
  final bool loading;
  final bool picking;
  final bool uploading;
  final bool trusted;
  final bool changed;
  final bool uncertain;
  final bool uploadSucceeded;
}
