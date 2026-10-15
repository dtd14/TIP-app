import '../entities/notification_realtime_event.dart';

abstract interface class NotificationRealtimeRepository {
  /// Each subscription owns a connection; cancellation closes it and cancels retries.
  Stream<NotificationRealtimeEvent> watch();
  Future<void> dispose();
}
