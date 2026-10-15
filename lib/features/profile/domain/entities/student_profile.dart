import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.accountId,
    required this.fullName,
    required this.studentCode,
    required this.major,
    required this.university,
    required this.status,
    required this.accountStatus,
    required this.email,
    this.phone,
    this.semester,
    this.className,
    this.cvUrl,
    this.universityId,
    this.internships = const [],
  });
  final String id, accountId, fullName, studentCode, major, university;
  final String status, accountStatus, email;
  final String? phone, className, cvUrl, universityId;
  final int? semester;
  final List<InternshipRegistration> internships;

  InternshipRegistration? currentInternship(DateTime now) {
    final available =
        internships
            .where(
              (item) =>
                  item.periodStatus != 'CANCELLED' &&
                  item.periodStatus != 'DRAFT',
            )
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
    for (final item in available) {
      if (!now.isBefore(item.startDate) && !now.isAfter(item.endDate)) {
        return item;
      }
    }
    final upcoming =
        available.where((item) => now.isBefore(item.startDate)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcoming.isNotEmpty ? upcoming.first : available.firstOrNull;
  }
}
