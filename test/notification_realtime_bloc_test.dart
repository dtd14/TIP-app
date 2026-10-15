import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/features/notifications/domain/entities/notification_realtime_event.dart';
import 'package:tip_app/features/notifications/domain/usecases/get_notifications.dart';
import 'package:tip_app/features/notifications/domain/usecases/get_unread_notification_count.dart';
import 'package:tip_app/features/notifications/domain/usecases/read_notification.dart';
import 'package:tip_app/features/notifications/domain/usecases/read_all_notifications.dart';
import 'package:tip_app/features/notifications/domain/usecases/watch_notification_updates.dart';
import 'package:tip_app/features/notifications/presentation/bloc/notifications/notifications_bloc.dart';
import 'support/notification_fakes.dart';
import 'notification_realtime_test.dart' show eventually;

void main() {
  late FakeNotificationsRepository repository;
  late FakeNotificationRealtimeRepository realtime;
  late NotificationsBloc bloc;
  setUp(() {
    repository = FakeNotificationsRepository()..items = [notification()];
    realtime = FakeNotificationRealtimeRepository();
    bloc = NotificationsBloc(
      GetNotifications(repository),
      GetUnreadNotificationCount(repository),
      ReadNotification(repository),
      ReadAllNotifications(repository),
      watchUpdates: WatchNotificationUpdates(realtime),
      invalidationDelay: const Duration(milliseconds: 3),
      pollInterval: const Duration(milliseconds: 20),
      reconciliationInterval: const Duration(milliseconds: 80),
    );
    bloc.startRealtime();
  });
  tearDown(() async {
    await bloc.close();
    await realtime.dispose();
  });
  NotificationDataChanged change(String id) => NotificationDataChanged(
    eventId: id,
    reason: NotificationChangeReason.created,
    emittedAt: DateTime.utc(2026, 10, 8),
  );

  test('ready synchronizes count; closed list is not fetched', () async {
    realtime.emit(const NotificationRealtimeReady());
    await eventually(() => bloc.state.unreadCount == 1);
    expect(repository.queries, isEmpty);
  });

  test(
    'change bursts and duplicate IDs coalesce into one visible-list refresh',
    () async {
      bloc.setListVisible(true);
      realtime.emit(change('a'));
      realtime.emit(change('a'));
      realtime.emit(change('b'));
      await eventually(() => bloc.state.loaded);
      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(repository.countCalls, 1);
      expect(repository.queries, hasLength(1));
      expect(bloc.state.items.single.id, notificationId);
    },
  );

  test(
    'changes during an in-flight synchronization schedule one follow-up',
    () async {
      final pending = Completer<int>();
      repository.onCount = () =>
          repository.countCalls == 1 ? pending.future : Future.value(2);
      realtime.emit(change('a'));
      await eventually(() => repository.countCalls == 1);
      realtime.emit(change('b'));
      realtime.emit(change('c'));
      pending.complete(1);
      await eventually(() => bloc.state.unreadCount == 2);
      expect(repository.countCalls, 2);
    },
  );

  test(
    'periodic reconciliation recovers an invalidation lost on a healthy socket',
    () async {
      repository.items = [];
      realtime.emit(
        const NotificationRealtimeStatusChanged(
          NotificationRealtimeStatus.connected,
        ),
      );
      realtime.emit(const NotificationRealtimeReady());
      await eventually(() => bloc.state.unreadCount == 0);
      repository.items = [notification()];
      // No notifications.changed event was delivered for the database change.
      await eventually(() => bloc.state.unreadCount == 1);
      expect(bloc.state.realtimeStatus, NotificationRealtimeStatus.connected);
    },
  );

  test('REST polling slows on connected and stops on pause', () async {
    realtime.emit(
      const NotificationRealtimeStatusChanged(
        NotificationRealtimeStatus.disabled,
      ),
    );
    await eventually(() => repository.countCalls >= 1);
    realtime.emit(
      const NotificationRealtimeStatusChanged(
        NotificationRealtimeStatus.connected,
      ),
    );
    await eventually(
      () => bloc.state.realtimeStatus == NotificationRealtimeStatus.connected,
    );
    final calls = repository.countCalls;
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(repository.countCalls, calls);
    await bloc.pauseRealtime();
    expect(realtime.cancellations, 1);
    realtime.emit(change('after-pause'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repository.countCalls, calls);
  });
}
