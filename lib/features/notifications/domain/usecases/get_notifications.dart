import 'package:tip_app/core/domain/entities/page_slice.dart';
import '../entities/app_notification.dart';
import '../repositories/notifications_repository.dart';

class GetNotifications {
  const GetNotifications(this.repository);
  final NotificationsRepository repository;
  Future<PageSlice<AppNotification>> call({
    NotificationFilter filter = NotificationFilter.all,
    int page = 1,
    int limit = 20,
  }) => repository.list(filter: filter, page: page, limit: limit);
}
