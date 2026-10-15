import 'package:tip_app/core/errors/failures.dart';
import 'package:dio/dio.dart';
import 'package:tip_app/core/network/api_client.dart';
import 'package:tip_app/core/network/api_endpoints.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';

class StudentProfileRemoteDataSource {
  const StudentProfileRemoteDataSource(this.client);
  final ApiClient client;
  Options get _authenticated =>
      Options(extra: {'requiresAuth': true, 'requiresBearerAuth': true});
  Future<Object?> profile() async => (await client.dio.get<Object?>(
    ApiEndpoints.studentProfile,
    options: _authenticated,
  )).data;

  Future<void> update({String? fullName, String? phone, CvUpload? cv}) async {
    final fields = {'fullName': ?fullName?.trim(), 'phone': ?phone?.trim()};
    if (fields.isEmpty && cv == null) {
      throw const AuthFailure(
        FailureKind.validation,
        'Chưa có thay đổi để lưu.',
      );
    }
    // Dio sets the multipart boundary. No academic fields are ever submitted.
    final Object data = cv == null
        ? fields
        : FormData.fromMap({
            ...fields,
            'cv': MultipartFile.fromBytes(
              cv.bytes,
              filename: cv.name,
              contentType: DioMediaType('application', 'pdf'),
            ),
          });
    await client.dio.patch<Object?>(
      ApiEndpoints.studentProfile,
      data: data,
      options: Options(
        extra: {'requiresAuth': true, 'requiresBearerAuth': true},
      ),
    );
  }
}
