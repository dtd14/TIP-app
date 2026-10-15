import 'package:tip_app/features/student_enrollment/data/datasources/student_enrollment_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/errors/api_error_mapper.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'package:tip_app/features/student_enrollment/domain/enrollment_validation.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/data/models/student_enrollment_model.dart';

class StudentEnrollmentRepositoryImpl implements StudentEnrollmentRepository {
  const StudentEnrollmentRepositoryImpl(this.remote);
  final StudentEnrollmentRemoteDataSource remote;

  Future<T> _request<T>(
    Future<T> Function() call, {
    bool mutation = false,
  }) async {
    try {
      return await call();
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        final data = error.response?.data;
        final message = data is Map<String, dynamic> ? data['message'] : null;
        if (message == 'Mã sinh viên đã được sử dụng tại trường này.') {
          throw const AuthFailure(
            FailureKind.conflict,
            'Mã sinh viên đã được sử dụng tại trường này. Kiểm tra lại mã hoặc liên hệ nhà trường.',
            fieldErrors: {
              'studentCode': 'Mã sinh viên đã được sử dụng tại trường này.',
            },
          );
        }
        throw const AuthFailure(
          FailureKind.conflict,
          'Yêu cầu, tài khoản hoặc mã sinh viên đã thay đổi hay trùng dữ liệu. Danh sách sẽ được tải lại.',
        );
      }
      if (error.response?.statusCode == 404) {
        throw const AuthFailure(
          FailureKind.server,
          'Trường, ngành hoặc yêu cầu không còn khả dụng. Vui lòng tải lại.',
        );
      }
      if (mutation &&
          {
            DioExceptionType.sendTimeout,
            DioExceptionType.receiveTimeout,
          }.contains(error.type)) {
        throw const AuthFailure(
          FailureKind.timeout,
          'Chưa xác nhận được kết quả thao tác. Hãy tải lại danh sách trước khi gửi lại.',
        );
      }
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 422) {
        final data = error.response?.data;
        final message = data is Map<String, dynamic> ? data['message'] : null;
        if (message ==
            'Ngành học không thuộc trường đã chọn hoặc trường chưa được xác minh.') {
          throw const AuthFailure(
            FailureKind.validation,
            'Ngành học không thuộc trường đã chọn hoặc trường chưa được xác minh. Vui lòng chọn lại trường và ngành.',
          );
        }
        throw const AuthFailure(
          FailureKind.validation,
          'Thông tin chưa hợp lệ. Kiểm tra thông tin ghi danh, từ khóa tìm kiếm hoặc lý do xét duyệt.',
        );
      }
      throw ApiErrorMapper.map(error, ApiOperation.profile).failure;
    } on ApiException catch (error) {
      throw error.failure;
    } on FormatException {
      throw const AuthFailure(
        FailureKind.server,
        'Dữ liệu ghi danh trả về chưa hợp lệ. Vui lòng thử lại.',
      );
    } on AuthFailure {
      rethrow;
    } on Object {
      throw const AuthFailure(
        FailureKind.unexpected,
        'Chưa thể xử lý yêu cầu ghi danh. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<List<EnrollmentSchool>> universities({String keyword = ''}) =>
      _request(() async {
        _validateKeyword(keyword);
        final data = await remote.universities(keyword: keyword);
        return List.unmodifiable(
          StudentEnrollmentModel.list(data).map(StudentEnrollmentModel.school),
        );
      });
  @override
  Future<List<EnrollmentMajor>> majors(String universityId) =>
      _request(() async {
        final data = await remote.majors(universityId);
        return List.unmodifiable(
          StudentEnrollmentModel.list(data).map(
            (item) =>
                StudentEnrollmentModel.major(item, universityId: universityId),
          ),
        );
      });
  @override
  Future<List<StudentEnrollment>> mine() => _request(() async {
    final data = await remote.mine();
    return List.unmodifiable(
      StudentEnrollmentModel.list(data).map(StudentEnrollmentModel.enrollment),
    );
  });
  @override
  Future<void> submit(StudentEnrollmentInput input) => _request(() async {
    final failure = EnrollmentValidation.input(input);
    if (failure != null) throw failure;
    await remote.submit(input);
  }, mutation: true);
  @override
  Future<void> cancel(String id) => _request(() async {
    await remote.cancel(id);
  }, mutation: true);
  @override
  Future<EnrollmentQueue> queue({
    String? status,
    String keyword = '',
    int page = 1,
  }) => _request(() async {
    _validateKeyword(keyword);
    final data = await remote.queue(
      status: status,
      keyword: keyword,
      page: page,
    );
    return StudentEnrollmentModel.queue(data);
  });
  @override
  Future<void> review(String id, {required bool approve, String? reason}) =>
      _request(() async {
        final reasonError = approve
            ? null
            : EnrollmentValidation.reason(reason);
        if (reasonError != null) {
          throw AuthFailure(
            FailureKind.validation,
            reasonError,
            fieldErrors: {'reason': reasonError},
          );
        }
        await remote.review(id, approve: approve, reason: reason);
      }, mutation: true);

  static void _validateKeyword(String keyword) {
    final error = EnrollmentValidation.keyword(keyword);
    if (error != null) throw AuthFailure(FailureKind.validation, error);
  }
}
