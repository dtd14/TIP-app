import '../entities/app_notification.dart';
import '../repositories/notifications_repository.dart';

class ReadNotification {
  const ReadNotification(this.repository);
  final NotificationsRepository repository;
  Future<AppNotification> call(String id) => repository.read(id);
}
