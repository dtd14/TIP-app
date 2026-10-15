import '../repositories/notifications_repository.dart';

class ReadAllNotifications {
  const ReadAllNotifications(this.repository);
  final NotificationsRepository repository;
  Future<int> call() => repository.readAll();
}
