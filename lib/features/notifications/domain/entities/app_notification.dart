class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    required this.readAt,
  });
  final String id, type, title, body, entityType, entityId;
  final DateTime createdAt;
  final DateTime? readAt;
  bool get isUnread => readAt == null;
}

enum NotificationFilter { all, unread }
