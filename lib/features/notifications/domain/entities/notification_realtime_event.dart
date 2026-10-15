import 'package:tip_app/core/errors/failures.dart';

enum NotificationRealtimeStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  disabled,
}

enum NotificationChangeReason { created, read, readAll }

sealed class NotificationRealtimeEvent {
  const NotificationRealtimeEvent();
}

class NotificationRealtimeStatusChanged extends NotificationRealtimeEvent {
  const NotificationRealtimeStatusChanged(this.status, {this.failure});
  final NotificationRealtimeStatus status;
  final AuthFailure? failure;
}

class NotificationDataChanged extends NotificationRealtimeEvent {
  const NotificationDataChanged({
    required this.eventId,
    required this.reason,
    required this.emittedAt,
  });
  final String eventId;
  final NotificationChangeReason reason;
  final DateTime emittedAt;
}

class NotificationRealtimeReady extends NotificationRealtimeEvent {
  const NotificationRealtimeReady();
}
