import 'package:dio/dio.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/errors/api_error_mapper.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';
import 'package:tip_app/core/data/json_decoder.dart';
import 'package:tip_app/features/applications/data/models/application_model.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/applications/data/datasources/application_remote_data_source.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  const ApplicationRepositoryImpl(this.remote);
  final ApplicationRemoteDataSource remote;
  @override
  Future<PageSlice<ApplicationOverview>> getApplications({
    int page = 1,
    int limit = 20,
    String? status,
  }) => _request(
    () async => JsonDecoder.page(
      await remote.applications(page: page, limit: limit, status: status),
      ApplicationModel.application,
    ),
  );

  @override
  Future<ApplicationDetail> getApplication(String id, AuthUser user) =>
      _request(
        () async => _ownedApplication(await remote.application(id), id, user),
        notFoundMessage:
            'Không tìm thấy đơn ứng tuyển trong tài khoản của bạn.',
      );

  @override
  Future<ApplicationDetail> withdrawApplication(String id, AuthUser user) =>
      _request(
        () async => _ownedApplication(await remote.withdraw(id), id, user),
        withdrawing: true,
        notFoundMessage:
            'Không tìm thấy đơn ứng tuyển trong tài khoản của bạn.',
      );

  @override
  Future<ApplicationOverview> applyForOpportunity(String id) => _request(
    () async => ApplicationModel.application(await remote.apply(id)),
    applying: true,
    notFoundMessage: 'Cơ hội không còn khả dụng. Vui lòng tải lại danh sách.',
  );

  ApplicationDetail _ownedApplication(Object? data, String id, AuthUser user) {
    final detail = ApplicationModel.applicationDetail(data);
    if (!user.canAccessStudentApp ||
        detail.application.id != id ||
        detail.studentId != user.studentId) {
      throw const FormatException('Application identity mismatch');
    }
    return detail;
  }

  Future<T> _request<T>(
    Future<T> Function() action, {
    bool applying = false,
    bool withdrawing = false,
    String? notFoundMessage,
  }) async {
    try {
      return await action();
    } on DioException catch (error) {
      if (withdrawing && error.response?.statusCode == 409) {
        throw const AuthFailure(
          FailureKind.conflict,
          'Đơn đã thay đổi. Vui lòng tải lại trạng thái trước khi thao tác tiếp.',
        );
      }
      if (withdrawing && error.response?.statusCode == 400) {
        throw const AuthFailure(
          FailureKind.validation,
          'Chỉ có thể rút đơn đang chờ duyệt hoặc đang xem xét. Vui lòng tải lại đơn.',
        );
      }
      if (applying && error.response?.statusCode == 409) {
        throw const AuthFailure(
          FailureKind.validation,
          'Bạn đã ứng tuyển cơ hội này. Hãy kiểm tra mục Ứng tuyển.',
        );
      }
      if (applying && error.response?.statusCode == 400) {
        throw const AuthFailure(
          FailureKind.validation,
          'Cơ hội đã đóng, hết hạn hoặc chưa có hạn ứng tuyển. Vui lòng kiểm tra lại.',
        );
      }
      if (error.response?.statusCode == 404 && notFoundMessage != null) {
        throw AuthFailure(FailureKind.server, notFoundMessage);
      }
      if ((applying || withdrawing) &&
          {
            DioExceptionType.sendTimeout,
            DioExceptionType.receiveTimeout,
          }.contains(error.type)) {
        throw AuthFailure(
          FailureKind.timeout,
          withdrawing
              ? 'Chưa xác nhận được kết quả rút đơn. Hãy tải lại trạng thái trước khi thử lại.'
              : 'Chưa xác nhận được kết quả gửi đơn. Hãy kiểm tra mục Ứng tuyển trước khi gửi lại.',
        );
      }
      throw ApiErrorMapper.map(error, ApiOperation.profile).failure;
    } on ApiException catch (error) {
      throw error.failure;
    } on FormatException {
      throw const AuthFailure(
        FailureKind.server,
        'Dữ liệu trả về chưa hợp lệ. Vui lòng thử lại sau.',
      );
    } on AuthFailure {
      rethrow;
    } on Object {
      throw const AuthFailure(
        FailureKind.unexpected,
        'Chưa thể tải dữ liệu. Vui lòng thử lại.',
      );
    }
  }
}
