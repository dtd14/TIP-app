import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import '../bloc/notifications/notifications_bloc.dart';
import '../bloc/notifications/notifications_state.dart';
import '../pages/notifications_page.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    final bloc = context.read<NotificationsBloc>();
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              BlocProvider.value(value: bloc, child: const NotificationsPage()),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<NotificationsBloc, NotificationsState>(
        buildWhen: (previous, current) =>
            previous.unreadCount != current.unreadCount ||
            previous.countFailure != current.countFailure,
        builder: (context, state) => IconButton(
          key: const Key('openNotifications'),
          tooltip: state.unreadCount == null
              ? 'Thông báo'
              : 'Thông báo (${state.unreadCount} chưa đọc)',
          onPressed: _open,
          icon: Badge(
            key: const Key('notificationBadge'),
            isLabelVisible: (state.unreadCount ?? 0) > 0,
            label: Text(
              (state.unreadCount ?? 0) > 99
                  ? '99+'
                  : '${state.unreadCount ?? 0}',
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.muted,
              size: 22,
            ),
          ),
        ),
      );
}
