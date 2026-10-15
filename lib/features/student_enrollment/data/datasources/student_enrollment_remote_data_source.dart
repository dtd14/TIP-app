import 'package:dio/dio.dart';
import 'package:tip_app/core/network/api_client.dart';
import 'package:tip_app/core/network/api_endpoints.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class StudentEnrollmentRemoteDataSource {
  const StudentEnrollmentRemoteDataSource(this.client);
  final ApiClient client;
  static const _base = ApiEndpoints.studentEnrollments;
  Options get _authenticated =>
      Options(extra: {'requiresAuth': true, 'requiresBearerAuth': true});
  Future<Object?> universities({String keyword = ''}) async {
    final data = (await client.dio.get<Object?>(
      '$_base/universities',
      queryParameters: {
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      },
      options: _authenticated,
    )).data;
    return data;
  }

  Future<Object?> majors(String universityId) async {
    final data = (await client.dio.get<Object?>(
      '$_base/universities/${Uri.encodeComponent(universityId)}/majors',
      options: _authenticated,
    )).data;
    return data;
  }

  Future<Object?> mine() async {
    final data = (await client.dio.get<Object?>(
      '$_base/me',
      options: _authenticated,
    )).data;
    return data;
  }

  Future<void> submit(StudentEnrollmentInput input) async {
    await client.dio.post<Object?>(
      _base,
      options: _authenticated,
      data: {
        'universityId': input.universityId,
        'majorId': input.majorId,
        'studentCode': input.studentCode.trim(),
        'className': input.className.trim(),
        'semester': input.semester,
      },
    );
  }

  Future<void> cancel(String id) async {
    await client.dio.patch<Object?>(
      '$_base/${Uri.encodeComponent(id)}/cancel',
      options: _authenticated,
    );
  }

  Future<Object?> queue({
    String? status,
    String keyword = '',
    int page = 1,
  }) async {
    final data = (await client.dio.get<Object?>(
      _base,
      options: _authenticated,
      queryParameters: {
        'page': page,
        'limit': 20,
        'status': ?status,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      },
    )).data;
    return data;
  }

  Future<void> review(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    await client.dio.patch<Object?>(
      '$_base/${Uri.encodeComponent(id)}/review',
      options: _authenticated,
      data: {
        'decision': approve ? 'APPROVED' : 'REJECTED',
        if (!approve) 'reason': reason!.trim(),
      },
    );
  }
}
