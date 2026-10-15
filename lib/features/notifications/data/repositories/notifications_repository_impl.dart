import 'package:tip_app/core/data/api_request.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/core/errors/failures.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_data_source.dart';
import '../models/notification_model.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this.remote);
  final NotificationsRemoteDataSource remote;

  @override
  Future<PageSlice<AppNotification>> list({
    NotificationFilter filter = NotificationFilter.all,
    int page = 1,
    int limit = 20,
  }) => apiRequest(() async {
    if (page < 1 || page > 100000 || limit < 1 || limit > 100) {
      throw const AuthFailure(
        FailureKind.validation,
        'Tham số phân trang thông báo chưa hợp lệ.',
      );
    }
    final result = NotificationModel.page(
      await remote.list(filter: filter.name, page: page, limit: limit),
    );
    if (result.page != page ||
        result.limit != limit ||
        (filter == NotificationFilter.unread &&
            result.items.any((item) => !item.isUnread))) {
      throw const FormatException('Notification page does not match query');
    }
    return result;
  });

  @override
  Future<int> unreadCount() => apiRequest(
    () async => NotificationModel.count(await remote.unreadCount()),
  );

  @override
  Future<AppNotification> read(String id) => apiRequest(() async {
    final result = NotificationModel.fromJson(await remote.read(id));
    if (result.id != id || result.isUnread) {
      throw const FormatException(
        'Notification read result does not match request',
      );
    }
    return result;
  }, notFoundMessage: 'Không tìm thấy thông báo. Vui lòng tải lại danh sách.');

  @override
  Future<int> readAll() =>
      apiRequest(() async => NotificationModel.count(await remote.readAll()));
}
