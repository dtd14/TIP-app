import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import '../../domain/entities/app_notification.dart';
import '../bloc/notifications/notifications_bloc.dart';
import '../bloc/notifications/notifications_event.dart';
import '../bloc/notifications/notifications_state.dart';
import '../widgets/notification_card.dart';
import '../notification_navigation.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _opening = false;
  final _navigation = NotificationNavigation();
  late final NotificationsBloc _bloc;
  @override
  void initState() {
    super.initState();
    _bloc = context.read<NotificationsBloc>();
    _bloc.setListVisible(true);
    _bloc.dispatch(NotificationsRefreshRequested());
  }

  @override
  void dispose() {
    _bloc.setListVisible(false);
    super.dispose();
  }

  Future<void> _open(AppNotification item) async {
    if (_opening) return;
    _opening = true;
    try {
      final bloc = context.read<NotificationsBloc>();
      if (item.isUnread) {
        await bloc.dispatch(NotificationReadRequested(item.id));
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.title.isEmpty ? 'Thông báo' : item.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notificationTime(item.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              SelectableText(
                item.body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 20),
              if (_navigation.canOpen(context, item)) ...[
                FilledButton(
                  key: const Key('openNotificationRelated'),
                  onPressed: () => _navigation.open(context, item),
                  child: const Text('Xem nội dung liên quan'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  Widget _bounded(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: child,
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<NotificationsBloc, NotificationsState>(
    builder: (context, state) {
      final bloc = context.read<NotificationsBloc>();
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Thông báo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => bloc.dispatch(NotificationsRefreshRequested()),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _bounded(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DashboardPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeading(
                                  'Cập nhật của bạn',
                                  icon: Icons.notifications_none_rounded,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  state.unreadCount == null
                                      ? 'Theo dõi các cập nhật mới trong tài khoản.'
                                      : '${state.unreadCount} thông báo chưa đọc',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  key: const Key('readAllNotifications'),
                                  onPressed:
                                      !state.busy &&
                                          state.loaded &&
                                          (state.unreadCount != 0 ||
                                              state.items.any(
                                                (item) => item.isUnread,
                                              ))
                                      ? () => bloc.dispatch(
                                          AllNotificationsReadRequested(),
                                        )
                                      : null,
                                  icon: const Icon(
                                    Icons.done_all_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Đánh dấu tất cả đã đọc',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: NotificationFilter.values
                                .map(
                                  (filter) => ChoiceChip(
                                    key: Key(
                                      'notificationFilter-${filter.name}',
                                    ),
                                    selected: state.filter == filter,
                                    showCheckmark: false,
                                    selectedColor: AppColors.primary,
                                    labelStyle: TextStyle(
                                      color: state.filter == filter
                                          ? Colors.white
                                          : AppColors.text,
                                    ),
                                    label: Text(
                                      filter == NotificationFilter.all
                                          ? 'Tất cả'
                                          : 'Chưa đọc',
                                    ),
                                    onSelected: state.busy
                                        ? null
                                        : (_) => bloc.dispatch(
                                            NotificationsFilterChanged(filter),
                                          ),
                                  ),
                                )
                                .toList(),
                          ),
                          if (state.loaded) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${state.total} thông báo${state.filter == NotificationFilter.unread ? ' chưa đọc' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                          if (state.loading || state.mutating) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(minHeight: 3),
                          ],
                          if (state.failure != null) ...[
                            const SizedBox(height: 12),
                            DashboardPanel(
                              child: Column(
                                children: [
                                  Text(
                                    state.failure!.message,
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    key: const Key('retryNotifications'),
                                    onPressed: state.busy ? null : bloc.retry,
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (state.countFailure != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              state.countFailure!.message,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: state.loadingCount || state.busy
                                    ? null
                                    : () => bloc.dispatch(
                                        UnreadNotificationCountRequested(),
                                      ),
                                child: const Text('Tải lại số chưa đọc'),
                              ),
                            ),
                          ],
                          if (state.loaded &&
                              !state.loading &&
                              state.failure == null &&
                              state.items.isEmpty)
                            DashboardPanel(
                              child: DashboardEmpty(
                                state.filter == NotificationFilter.unread
                                    ? 'Bạn đã đọc tất cả thông báo.'
                                    : 'Bạn chưa có thông báo nào.',
                                icon: Icons.notifications_none_rounded,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _bounded(
                          NotificationCard(
                            item: item,
                            onOpen: state.busy ? null : () => _open(item),
                            onRead: state.busy
                                ? null
                                : () => bloc.dispatch(
                                    NotificationReadRequested(item.id),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _bounded(
                      state.hasNext && state.failure == null
                          ? OutlinedButton(
                              key: const Key('loadMoreNotifications'),
                              onPressed: state.busy
                                  ? null
                                  : () => bloc.dispatch(
                                      NotificationsNextPageRequested(),
                                    ),
                              child: const Text('Tải thêm thông báo'),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
