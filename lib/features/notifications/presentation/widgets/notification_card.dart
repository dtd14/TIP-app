import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import '../../domain/entities/app_notification.dart';

String notificationTime(DateTime date) {
  final local = date.toLocal();
  return '${DateFormatter.date(date)} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.item,
    required this.onOpen,
    this.onRead,
  });
  final AppNotification item;
  final VoidCallback? onOpen, onRead;

  @override
  Widget build(BuildContext context) => Material(
    color: item.isUnread ? AppColors.field : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: item.isUnread
            ? const Color(0xFFDAE5FF)
            : const Color(0xFFEEF1F8),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: Key('notification-${item.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                item.isUnread
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.isUnread) ...[
                    const Text(
                      'Chưa đọc',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                  Text(
                    item.title.isEmpty ? 'Thông báo' : item.title,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: item.isUnread
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    notificationTime(item.createdAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (item.isUnread)
              IconButton(
                key: Key('readNotification-${item.id}'),
                tooltip: 'Đánh dấu đã đọc',
                onPressed: onRead,
                icon: const Icon(
                  Icons.done_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
