import 'package:tip_app/features/applications/domain/entities/application_overview.dart';

class ApplicationDetail {
  const ApplicationDetail({
    required this.application,
    required this.studentId,
    required this.fullName,
    required this.studentCode,
    required this.email,
    required this.major,
    required this.university,
    required this.opportunityId,
    required this.opportunityStatus,
    this.phone,
    this.cvUrl,
    this.deadline,
    this.vacancies,
  });
  final ApplicationOverview application;
  final String studentId, fullName, studentCode, email, major, university;
  final String opportunityId, opportunityStatus;
  final String? phone, cvUrl;
  final DateTime? deadline;
  final int? vacancies;
}
