import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/profile/data/models/student_profile_model.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/profile/data/datasources/student_profile_remote_data_source.dart';
import 'package:tip_app/core/data/api_request.dart';
import 'package:dio/dio.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/api_error_mapper.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';

class StudentProfileRepositoryImpl implements StudentProfileRepository {
  const StudentProfileRepositoryImpl(this.remote);
  final StudentProfileRemoteDataSource remote;
  @override
  Future<StudentProfile> getStudentProfile(
    AuthUser user,
  ) => apiRequest(() async {
    final profile = StudentProfileModel.profile(await remote.profile());
    if (profile.id != user.studentId || profile.accountId != user.id) {
      throw const FormatException('Profile identity mismatch');
    }
    if (profile.status != 'ACTIVE' || profile.accountStatus != 'ACTIVE') {
      throw const AuthFailure(
        FailureKind.inactiveAccount,
        'Tài khoản hoặc hồ sơ sinh viên hiện không hoạt động. Vui lòng liên hệ nhà trường.',
      );
    }
    return profile;
  });

  @override
  Future<void> update({String? fullName, String? phone, CvUpload? cv}) async {
    if (fullName != null && fullName.trim().isEmpty) {
      throw const AuthFailure(
        FailureKind.validation,
        'Vui lòng nhập họ và tên.',
      );
    }
    if (fullName == null && phone == null && cv == null) {
      throw const AuthFailure(
        FailureKind.validation,
        'Chưa có thay đổi để lưu.',
      );
    }
    try {
      await remote.update(fullName: fullName, phone: phone, cv: cv);
    } on DioException catch (error) {
      if (error.response?.statusCode == 413) {
        throw const AuthFailure(
          FailureKind.validation,
          'CV không được vượt quá 4 MiB.',
        );
      }
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 422) {
        throw const AuthFailure(
          FailureKind.validation,
          'Thông tin hoặc tệp PDF chưa hợp lệ. Vui lòng kiểm tra và thử lại.',
        );
      }
      if ({
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(error.type)) {
        throw const AuthFailure(
          FailureKind.timeout,
          'Chưa xác nhận được cập nhật. Hãy tải lại hồ sơ trước khi lưu lại.',
        );
      }
      throw ApiErrorMapper.map(error, ApiOperation.profile).failure;
    } on ApiException catch (error) {
      throw error.failure;
    }
  }
}
