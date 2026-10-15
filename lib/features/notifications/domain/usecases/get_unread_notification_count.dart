import '../repositories/notifications_repository.dart';

class GetUnreadNotificationCount {
  const GetUnreadNotificationCount(this.repository);
  final NotificationsRepository repository;
  Future<int> call() => repository.unreadCount();
}
