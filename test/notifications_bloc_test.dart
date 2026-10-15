import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/notifications/domain/entities/app_notification.dart';
import 'package:tip_app/features/notifications/domain/usecases/get_notifications.dart';
import 'package:tip_app/features/notifications/domain/usecases/get_unread_notification_count.dart';
import 'package:tip_app/features/notifications/domain/usecases/read_notification.dart';
import 'package:tip_app/features/notifications/domain/usecases/read_all_notifications.dart';
import 'package:tip_app/features/notifications/presentation/bloc/notifications/notifications_bloc.dart';
import 'package:tip_app/features/notifications/presentation/bloc/notifications/notifications_event.dart';
import 'support/notification_fakes.dart';

NotificationsBloc notificationsBloc(FakeNotificationsRepository repository) =>
    NotificationsBloc(
      GetNotifications(repository),
      GetUnreadNotificationCount(repository),
      ReadNotification(repository),
      ReadAllNotifications(repository),
    );

void main() {
  test(
    'append failure retains rows and retries the same filtered page',
    () async {
      var fail = true;
      final repository = FakeNotificationsRepository()
        ..onList = (filter, page, limit) async {
          if (page == 2 && fail) {
            throw const AuthFailure(FailureKind.network, 'Offline');
          }
          return PageSlice(
            items: [notification(id: '$page')],
            total: 21,
            page: page,
            limit: limit,
          );
        };
      final bloc = notificationsBloc(repository);
      addTearDown(bloc.close);
      await bloc.dispatch(
        NotificationsFilterChanged(NotificationFilter.unread),
      );
      await bloc.dispatch(NotificationsNextPageRequested());
      expect(bloc.state.page, 1);
      expect(bloc.state.items.single.id, '1');
      expect(bloc.state.retryReset, false);
      fail = false;
      await bloc.retry();
      expect(repository.queries, [
        (NotificationFilter.unread, 1, 20),
        (NotificationFilter.unread, 2, 20),
        (NotificationFilter.unread, 2, 20),
      ]);
      expect(bloc.state.items.map((item) => item.id), ['2', '1']);
      expect(bloc.state.failure, isNull);
      await bloc.dispatch(NotificationsNextPageRequested());
      expect(repository.queries, hasLength(3));
    },
  );

  test(
    'read-all reloads count and leaves notifications arriving after cutoff unread',
    () async {
      final repository = FakeNotificationsRepository()
        ..items = [notification()];
      repository.onReadAll = () async {
        repository.items = [notification(read: true), notification(id: 'new')];
        return 87; // Affected rows are independent of the remaining unread count.
      };
      final bloc = notificationsBloc(repository);
      addTearDown(bloc.close);
      await bloc.dispatch(NotificationsRefreshRequested());
      await bloc.dispatch(AllNotificationsReadRequested());
      expect(bloc.state.unreadCount, 1);
      expect(bloc.state.items.where((item) => item.isUnread).single.id, 'new');
      expect(repository.countCalls, 2);
      expect(repository.readAllCalls, 1);
    },
  );

  test(
    'removing an unread row restarts offset pagination to avoid skipping rows',
    () async {
      final repository = FakeNotificationsRepository()
        ..items = List.generate(21, (index) => notification(id: '$index'));
      final bloc = notificationsBloc(repository);
      addTearDown(bloc.close);
      await bloc.dispatch(
        NotificationsFilterChanged(NotificationFilter.unread),
      );
      final id = bloc.state.items.first.id;
      await bloc.dispatch(NotificationReadRequested(id));
      expect(repository.queries.map((query) => query.$2), [1, 1]);
      expect(bloc.state.items, hasLength(20));
      expect(bloc.state.items.any((item) => item.id == id), false);
      expect(bloc.state.items.any((item) => item.id == '20'), true);
      expect(bloc.state.unreadCount, 20);
      expect(bloc.state.hasNext, false);
    },
  );

  test('failed count does not discard a successfully loaded list', () async {
    final repository = FakeNotificationsRepository()
      ..items = [notification()]
      ..onCount = () async =>
          throw const AuthFailure(FailureKind.network, 'Offline');
    final bloc = notificationsBloc(repository);
    addTearDown(bloc.close);
    await bloc.dispatch(NotificationsRefreshRequested());
    expect(bloc.state.loaded, true);
    expect(bloc.state.items, hasLength(1));
    expect(bloc.state.failure, isNull);
    expect(bloc.state.countFailure, isNotNull);
    expect(bloc.state.unreadCount, isNull);
  });

  test(
    'a slow older count cannot overwrite the count fetched with a refresh',
    () async {
      final pending = Completer<int>();
      var countRequests = 0;
      final repository = FakeNotificationsRepository()
        ..items = [notification()]
        ..onCount = () =>
            ++countRequests == 1 ? pending.future : Future.value(1);
      final bloc = notificationsBloc(repository);
      addTearDown(bloc.close);
      final initial = bloc.dispatch(UnreadNotificationCountRequested());
      await bloc.stream.firstWhere((state) => state.loadingCount);
      await bloc.dispatch(NotificationsRefreshRequested());
      expect(bloc.state.items, hasLength(1));
      expect(bloc.state.unreadCount, 1);
      pending.complete(99);
      await initial;
      expect(bloc.state.unreadCount, 1);
    },
  );

  test(
    'duplicate pending page requests and duplicate reads make one request',
    () async {
      final pending = Completer<PageSlice<AppNotification>>();
      final repository = FakeNotificationsRepository()
        ..items = [notification()]
        ..onList = (_, page, limit) => pending.future;
      final bloc = notificationsBloc(repository);
      addTearDown(bloc.close);
      final first = bloc.dispatch(NotificationsRefreshRequested());
      await bloc.stream.firstWhere((state) => state.loading);
      await bloc.dispatch(NotificationsRefreshRequested());
      expect(repository.queries, hasLength(1));
      pending.complete(
        PageSlice(items: repository.items, total: 1, page: 1, limit: 20),
      );
      await first;
      await bloc.dispatch(NotificationReadRequested(notificationId));
      await bloc.dispatch(NotificationReadRequested(notificationId));
      expect(repository.readCalls, 1);
      expect(bloc.state.items.single.isUnread, false);
    },
  );

  test('closed session ignores a pending list response', () async {
    final pending = Completer<PageSlice<AppNotification>>();
    final repository = FakeNotificationsRepository()
      ..onList = (_, page, limit) => pending.future;
    final bloc = notificationsBloc(repository);
    final request = bloc.dispatch(NotificationsRefreshRequested());
    await bloc.stream.firstWhere((state) => state.loading);
    final closing = bloc.close();
    pending.complete(
      PageSlice(items: [notification()], total: 1, page: 1, limit: 20),
    );
    await Future.wait([request, closing]);
    expect(bloc.state.items, isEmpty);
    expect(repository.countCalls, 0);
  });
}
