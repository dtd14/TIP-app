import 'dart:async';
import '../../../domain/entities/app_notification.dart';
import '../../../domain/entities/notification_realtime_event.dart';

sealed class NotificationsEvent {
  final Completer<void> completion = Completer<void>();
}

sealed class NotificationsActionEvent extends NotificationsEvent {}

class NotificationsRefreshRequested extends NotificationsActionEvent {}

class NotificationsNextPageRequested extends NotificationsActionEvent {}

class UnreadNotificationCountRequested extends NotificationsEvent {}

class NotificationsFilterChanged extends NotificationsActionEvent {
  NotificationsFilterChanged(this.filter);
  final NotificationFilter filter;
}

class NotificationReadRequested extends NotificationsActionEvent {
  NotificationReadRequested(this.id);
  final String id;
}

class AllNotificationsReadRequested extends NotificationsActionEvent {}

class NotificationsSynchronizationRequested extends NotificationsActionEvent {}

class NotificationRealtimeStatusReceived extends NotificationsEvent {
  NotificationRealtimeStatusReceived(this.event);
  final NotificationRealtimeStatusChanged event;
}
