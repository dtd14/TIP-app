sealed class EnrollmentLookupEvent {}

class EnrollmentSchoolSearchChanged extends EnrollmentLookupEvent {
  EnrollmentSchoolSearchChanged(this.keyword);
  final String keyword;
}

class EnrollmentSchoolsRequested extends EnrollmentLookupEvent {
  EnrollmentSchoolsRequested(this.keyword, {this.generation});
  final String keyword;
  final int? generation;
}

class EnrollmentMajorsRequested extends EnrollmentLookupEvent {
  EnrollmentMajorsRequested(this.universityId);
  final String universityId;
}
