import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/data/json_decoder.dart';
import 'package:tip_app/features/internships/data/models/internship_model.dart';

abstract final class StudentProfileModel {
  static StudentProfile profile(Object? value) {
    final data = JsonDecoder.object(value);
    final account = JsonDecoder.object(data['account']);
    final raw = data['internships'];
    if (raw is! List) throw const FormatException('Invalid internships');
    final semester = data['semester'];
    if (semester != null && semester is! int) {
      throw const FormatException('Invalid semester');
    }
    return StudentProfile(
      id: JsonDecoder.text(data, 'id'),
      accountId: JsonDecoder.text(data, 'accountId'),
      fullName: JsonDecoder.text(account, 'fullName'),
      email: JsonDecoder.text(account, 'email'),
      studentCode: JsonDecoder.text(data, 'studentCode'),
      major: JsonDecoder.text(JsonDecoder.object(data['major']), 'name'),
      university: JsonDecoder.text(
        JsonDecoder.object(data['university']),
        'name',
      ),
      status: JsonDecoder.text(data, 'status'),
      accountStatus: JsonDecoder.text(account, 'status'),
      phone: JsonDecoder.optionalText(account, 'phone'),
      semester: semester as int?,
      className: JsonDecoder.optionalText(data, 'className'),
      cvUrl: JsonDecoder.optionalText(data, 'cvUrl'),
      universityId:
          JsonDecoder.optionalText(data, 'universityId') ??
          JsonDecoder.optionalText(
            JsonDecoder.object(data['university']),
            'id',
          ),
      internships: List.unmodifiable(
        raw.map((item) {
          final registration = JsonDecoder.object(item);
          final period = JsonDecoder.object(registration['internshipPeriod']);
          return InternshipModel.registration(registration, period);
        }),
      ),
    );
  }
}
