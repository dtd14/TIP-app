import '../entities/notification_realtime_event.dart';
import '../repositories/notification_realtime_repository.dart';

class WatchNotificationUpdates {
  const WatchNotificationUpdates(this.repository);
  final NotificationRealtimeRepository repository;
  Stream<NotificationRealtimeEvent> call() => repository.watch();
}
