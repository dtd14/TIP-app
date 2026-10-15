import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/repositories/notification_realtime_repository.dart';
import '../../domain/usecases/watch_notification_updates.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/get_unread_notification_count.dart';
import '../../domain/usecases/read_notification.dart';
import '../../domain/usecases/read_all_notifications.dart';
import '../bloc/notifications/notifications_bloc.dart';
import '../bloc/notifications/notifications_event.dart';
import '../bloc/notifications/notifications_state.dart';

/// Owned by the authenticated navigator, so badge/list state cannot cross sessions.
class NotificationsSession extends StatelessWidget {
  const NotificationsSession({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) {
      final repository = context.read<NotificationsRepository>();
      return NotificationsBloc(
          GetNotifications(repository),
          GetUnreadNotificationCount(repository),
          ReadNotification(repository),
          ReadAllNotifications(repository),
          watchUpdates: WatchNotificationUpdates(
            context.read<NotificationRealtimeRepository>(),
          ),
        )
        ..dispatch(UnreadNotificationCountRequested())
        ..startRealtime();
    },
    child: _NotificationsLifecycle(child: child),
  );
}

class _NotificationsLifecycle extends StatefulWidget {
  const _NotificationsLifecycle({required this.child});
  final Widget child;
  @override
  State<_NotificationsLifecycle> createState() =>
      _NotificationsLifecycleState();
}

class _NotificationsLifecycleState extends State<_NotificationsLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final bloc = context.read<NotificationsBloc>();
      bloc.startRealtime();
      bloc.synchronize();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      context.read<NotificationsBloc>().pauseRealtime();
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<NotificationsBloc, NotificationsState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure ||
            previous.countFailure != current.countFailure ||
            previous.realtimeFailure != current.realtimeFailure,
        listener: (context, state) {
          final failure = state.failure?.kind == FailureKind.inactiveAccount
              ? state.failure
              : state.countFailure?.kind == FailureKind.inactiveAccount
              ? state.countFailure
              : state.realtimeFailure?.kind == FailureKind.inactiveAccount
              ? state.realtimeFailure
              : null;
          if (failure != null) {
            context.read<AuthBloc>().add(AuthAccessRestricted(failure));
          }
        },
        child: widget.child,
      );
}
