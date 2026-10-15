import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';

class InternshipContact {
  const InternshipContact({
    required this.name,
    required this.email,
    this.phone,
  });
  final String name, email;
  final String? phone;
}

class InternshipPlacement {
  const InternshipPlacement({
    required this.overview,
    required this.studentId,
    required this.companyId,
    required this.studentName,
    required this.studentCode,
    required this.university,
    this.registrationId,
    this.periodId,
    this.periodName,
    this.registrationStatus,
    this.opportunityId,
    this.applicationId,
    this.universitySupervisor,
    this.companySupervisor,
  });
  final PlacementOverview overview;
  final String studentId, companyId, studentName, studentCode, university;
  final String? registrationId, periodId, periodName, registrationStatus;
  final String? opportunityId, applicationId;
  final InternshipContact? universitySupervisor, companySupervisor;
}
