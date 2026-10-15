import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';
import 'package:tip_app/core/data/json_decoder.dart';

abstract final class ApplicationModel {
  static ApplicationOverview application(Object? value) {
    final data = JsonDecoder.object(value);
    final opportunity = JsonDecoder.object(data['opportunity']);
    return ApplicationOverview(
      id: JsonDecoder.text(data, 'id'),
      status: JsonDecoder.text(data, 'status'),
      title: JsonDecoder.text(opportunity, 'title'),
      company: JsonDecoder.text(
        JsonDecoder.object(opportunity['company']),
        'name',
      ),
      appliedAt: JsonDecoder.date(data, 'appliedAt'),
      updatedAt: JsonDecoder.optionalDate(data, 'updatedAt'),
      opportunityId: JsonDecoder.optionalText(opportunity, 'id'),
      type: JsonDecoder.optionalText(opportunity, 'type'),
      companyVerified:
          JsonDecoder.object(opportunity['company'])['status'] == 'VERIFIED',
      companyId: JsonDecoder.optionalText(
        JsonDecoder.object(opportunity['company']),
        'id',
      ),
    );
  }

  static ApplicationDetail applicationDetail(Object? value) {
    final data = JsonDecoder.object(value);
    final student = JsonDecoder.object(data['student']);
    final account = JsonDecoder.object(student['account']);
    final opportunity = JsonDecoder.object(data['opportunity']);
    final studentId = JsonDecoder.text(student, 'id');
    final opportunityId = JsonDecoder.text(opportunity, 'id');
    if (data['studentId'] != studentId ||
        data['opportunityId'] != opportunityId) {
      throw const FormatException('Application relation identity mismatch');
    }
    final vacancies = opportunity['vacancies'];
    if (vacancies != null && (vacancies is! int || vacancies < 1)) {
      throw const FormatException('Invalid application vacancies');
    }
    return ApplicationDetail(
      application: application(data),
      studentId: studentId,
      fullName: JsonDecoder.text(account, 'fullName'),
      email: JsonDecoder.text(account, 'email'),
      phone: JsonDecoder.optionalText(account, 'phone'),
      studentCode: JsonDecoder.text(student, 'studentCode'),
      cvUrl: JsonDecoder.optionalText(student, 'cvUrl'),
      major: JsonDecoder.text(JsonDecoder.object(student['major']), 'name'),
      university: JsonDecoder.text(
        JsonDecoder.object(data['university']),
        'name',
      ),
      opportunityId: opportunityId,
      opportunityStatus: JsonDecoder.text(opportunity, 'status'),
      deadline: JsonDecoder.optionalDate(opportunity, 'applicationDeadline'),
      vacancies: vacancies as int?,
    );
  }
}
