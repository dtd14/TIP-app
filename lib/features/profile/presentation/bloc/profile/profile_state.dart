import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';

class ProfileState {
  const ProfileState({
    required this.profile,
    required this.failure,
    required this.loading,
  });
  final StudentProfile? profile;
  final AuthFailure? failure;
  final bool loading;
}
