import 'dart:async';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

sealed class StudentEnrollmentEvent {
  final Completer<void> completion = Completer<void>();
}

class EnrollmentRefreshRequested extends StudentEnrollmentEvent {}

class EnrollmentNextPageRequested extends StudentEnrollmentEvent {}

class EnrollmentFilterChanged extends StudentEnrollmentEvent {
  EnrollmentFilterChanged({this.status, this.keyword = ''});
  final String? status;
  final String keyword;
}

class EnrollmentSubmitRequested extends StudentEnrollmentEvent {
  EnrollmentSubmitRequested(this.input);
  final StudentEnrollmentInput input;
}

class EnrollmentCancelRequested extends StudentEnrollmentEvent {
  EnrollmentCancelRequested(this.item);
  final StudentEnrollment item;
}

class EnrollmentReviewRequested extends StudentEnrollmentEvent {
  EnrollmentReviewRequested(this.item, {required this.approve, this.reason});
  final StudentEnrollment item;
  final bool approve;
  final String? reason;
}
