import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/core/data/json_decoder.dart';

abstract final class InternshipModel {
  static InternshipRegistration registration(
    Map<String, dynamic> data,
    Map<String, dynamic> period,
  ) {
    final periodId = JsonDecoder.optionalText(period, 'id');
    if (data['internshipPeriodId'] != null &&
        data['internshipPeriodId'] != periodId) {
      throw const FormatException('Internship period identity mismatch');
    }
    return InternshipRegistration(
      id: JsonDecoder.text(data, 'id'),
      periodId: periodId,
      name: JsonDecoder.text(period, 'name'),
      status: JsonDecoder.text(data, 'status'),
      periodStatus: JsonDecoder.text(period, 'status'),
      startDate: JsonDecoder.date(period, 'startDate'),
      endDate: JsonDecoder.date(period, 'endDate'),
      applyStartDate: JsonDecoder.optionalDate(period, 'applyStartDate'),
      applyEndDate: JsonDecoder.optionalDate(period, 'applyEndDate'),
      periodNumber: JsonDecoder.positiveInteger(period, 'periodNumber'),
      requiredHours: JsonDecoder.positiveInteger(period, 'requiredHours'),
      requiredWeeks: JsonDecoder.positiveInteger(period, 'requiredWeeks'),
    );
  }

  static PlacementOverview placement(Object? value) {
    final data = JsonDecoder.object(value);
    final supervisor = data['universitySupervisor'];
    return PlacementOverview(
      id: JsonDecoder.text(data, 'id'),
      title: JsonDecoder.text(data, 'positionTitle'),
      company: JsonDecoder.text(JsonDecoder.object(data['company']), 'name'),
      companyId: JsonDecoder.optionalText(
        JsonDecoder.object(data['company']),
        'id',
      ),
      status: JsonDecoder.text(data, 'status'),
      startDate: JsonDecoder.date(data, 'startDate'),
      endDate: JsonDecoder.date(data, 'endDate'),
      supervisor: supervisor == null
          ? null
          : JsonDecoder.text(
              JsonDecoder.object(JsonDecoder.object(supervisor)['account']),
              'fullName',
            ),
    );
  }

  static InternshipPlacement internshipPlacement(Object? value) {
    final data = JsonDecoder.object(value);
    final student = JsonDecoder.object(data['student']),
        company = JsonDecoder.object(data['company']);
    final university = JsonDecoder.object(data['university']);
    for (final (key, relation) in [
      ('studentId', student),
      ('companyId', company),
      ('universityId', university),
    ]) {
      if (JsonDecoder.text(data, key) != JsonDecoder.text(relation, 'id')) {
        throw const FormatException('Placement identity mismatch');
      }
    }
    String? relationId(String key, String relation) {
      final id = JsonDecoder.optionalText(data, key);
      final included = data[relation];
      if ((id == null) != (included == null) ||
          (included != null &&
              JsonDecoder.text(JsonDecoder.object(included), 'id') != id)) {
        throw const FormatException('Placement relation identity mismatch');
      }
      return id;
    }

    final registrationId = relationId(
      'studentInternshipId',
      'studentInternship',
    );
    final registration = data['studentInternship'] == null
        ? null
        : JsonDecoder.object(data['studentInternship']);
    final period = registration == null
        ? null
        : JsonDecoder.object(registration['internshipPeriod']);
    InternshipContact? supervisor(String key) {
      final value = data[key];
      if (value == null) return null;
      final account = JsonDecoder.object(JsonDecoder.object(value)['account']);
      return InternshipContact(
        name: JsonDecoder.text(account, 'fullName'),
        email: JsonDecoder.text(account, 'email'),
        phone: JsonDecoder.optionalText(account, 'phone'),
      );
    }

    return InternshipPlacement(
      overview: placement(data),
      studentId: JsonDecoder.text(student, 'id'),
      companyId: JsonDecoder.text(company, 'id'),
      studentName: JsonDecoder.text(
        JsonDecoder.object(student['account']),
        'fullName',
      ),
      studentCode: JsonDecoder.text(student, 'studentCode'),
      university: JsonDecoder.text(university, 'name'),
      registrationId: registrationId,
      periodId: period == null ? null : JsonDecoder.text(period, 'id'),
      periodName: period == null ? null : JsonDecoder.text(period, 'name'),
      registrationStatus: registration == null
          ? null
          : JsonDecoder.text(registration, 'status'),
      opportunityId: relationId('opportunityId', 'opportunity'),
      applicationId: relationId('applicationId', 'application'),
      universitySupervisor: supervisor('universitySupervisor'),
      companySupervisor: supervisor('companySupervisor'),
    );
  }
}
