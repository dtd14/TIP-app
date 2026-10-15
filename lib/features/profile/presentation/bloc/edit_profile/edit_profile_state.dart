import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';

class EditProfileState {
  const EditProfileState({
    required this.profile,
    required this.cv,
    required this.failure,
    required this.saving,
    required this.picking,
    required this.checking,
    required this.uncertain,
    required this.mayHaveChanged,
    required this.saved,
  });
  final StudentProfile profile;
  final CvUpload? cv;
  final AuthFailure? failure;
  final bool saving;
  final bool picking;
  final bool checking;
  final bool uncertain;
  final bool mayHaveChanged;
  final bool saved;
}
