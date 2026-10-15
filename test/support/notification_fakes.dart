import 'dart:async';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/notifications/domain/entities/app_notification.dart';
import 'package:tip_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:tip_app/features/notifications/domain/repositories/notification_realtime_repository.dart';
import 'package:tip_app/features/notifications/domain/entities/notification_realtime_event.dart';

const notificationId = '123e4567-e89b-42d3-a456-426614174000';

class FakeNotificationRealtimeRepository
    implements NotificationRealtimeRepository {
  FakeNotificationRealtimeRepository() {
    _events = StreamController<NotificationRealtimeEvent>.broadcast(
      onCancel: () => cancellations++,
    );
  }
  late final StreamController<NotificationRealtimeEvent> _events;
  int watches = 0, cancellations = 0;
  void emit(NotificationRealtimeEvent event) => _events.add(event);
  @override
  Stream<NotificationRealtimeEvent> watch() {
    watches++;
    return _events.stream;
  }

  @override
  Future<void> dispose() => _events.close();
}

AppNotification notification({
  String id = notificationId,
  bool read = false,
  String title = 'Cập nhật hồ sơ',
  String body = 'Hồ sơ của bạn đã được cập nhật.',
}) => AppNotification(
  id: id,
  type: 'PROFILE_UPDATED',
  title: title,
  body: body,
  entityType: 'Student',
  entityId: 'student-1',
  createdAt: DateTime.utc(2026, 10, 8, 8),
  readAt: read ? DateTime.utc(2026, 10, 8, 9) : null,
);

Map<String, Object?> notificationJson({
  String id = notificationId,
  bool read = false,
}) => {
  'id': id,
  'type': 'PROFILE_UPDATED',
  'title': 'Cập nhật hồ sơ',
  'body': 'Hồ sơ của bạn đã được cập nhật.',
  'entityType': 'Student',
  'entityId': 'student-1',
  'createdAt': '2026-10-08T08:00:00.000Z',
  'readAt': read ? '2026-10-08T09:00:00.000Z' : null,
};

class FakeNotificationsRepository implements NotificationsRepository {
  List<AppNotification> items = [];
  int countCalls = 0, readCalls = 0, readAllCalls = 0;
  final queries = <(NotificationFilter, int, int)>[];
  Future<PageSlice<AppNotification>> Function(NotificationFilter, int, int)?
  onList;
  Future<int> Function()? onCount, onReadAll;
  Future<AppNotification> Function(String)? onRead;

  @override
  Future<PageSlice<AppNotification>> list({
    NotificationFilter filter = NotificationFilter.all,
    int page = 1,
    int limit = 20,
  }) async {
    queries.add((filter, page, limit));
    if (onList != null) return onList!(filter, page, limit);
    final visible = items
        .where((item) => filter == NotificationFilter.all || item.isUnread)
        .toList();
    return PageSlice(
      items: List.unmodifiable(visible.skip((page - 1) * limit).take(limit)),
      total: visible.length,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<int> unreadCount() async {
    countCalls++;
    return onCount == null
        ? items.where((item) => item.isUnread).length
        : onCount!();
  }

  @override
  Future<AppNotification> read(String id) async {
    readCalls++;
    if (onRead != null) return onRead!(id);
    final index = items.indexWhere((item) => item.id == id);
    final previous = items[index];
    final updated = AppNotification(
      id: previous.id,
      type: previous.type,
      title: previous.title,
      body: previous.body,
      entityType: previous.entityType,
      entityId: previous.entityId,
      createdAt: previous.createdAt,
      readAt: DateTime.utc(2026, 10, 8, 9),
    );
    items = [...items]..[index] = updated;
    return updated;
  }

  @override
  Future<int> readAll() async {
    readAllCalls++;
    if (onReadAll != null) return onReadAll!();
    final unread = items.where((item) => item.isUnread).toList();
    for (final item in unread) {
      await read(item.id);
    }
    return unread.length;
  }
}
