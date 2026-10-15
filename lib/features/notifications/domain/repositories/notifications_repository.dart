import 'package:tip_app/core/domain/entities/page_slice.dart';
import '../entities/app_notification.dart';

abstract interface class NotificationsRepository {
  Future<PageSlice<AppNotification>> list({
    NotificationFilter filter = NotificationFilter.all,
    int page = 1,
    int limit = 20,
  });
  Future<int> unreadCount();
  Future<AppNotification> read(String id);

  /// Returns the number updated by the server, rather than the remaining unread count.
  Future<int> readAll();
}
