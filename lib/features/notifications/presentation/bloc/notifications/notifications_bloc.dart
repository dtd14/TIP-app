import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import '../../../domain/entities/app_notification.dart';
import '../../../domain/usecases/get_notifications.dart';
import '../../../domain/usecases/get_unread_notification_count.dart';
import '../../../domain/usecases/read_notification.dart';
import '../../../domain/usecases/read_all_notifications.dart';
import '../../../domain/usecases/watch_notification_updates.dart';
import '../../../domain/entities/notification_realtime_event.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc(
    this._getNotifications,
    this._getCount,
    this._read,
    this._readAll, {
    this._watchUpdates,
    this.pollInterval = const Duration(seconds: 30),
    this.reconciliationInterval = const Duration(minutes: 2),
    this.invalidationDelay = const Duration(milliseconds: 250),
  }) : super(const NotificationsState()) {
    on<NotificationRealtimeStatusReceived>((event, emit) {
      emit(
        state.copyWith(
          realtimeStatus: event.event.status,
          realtimeFailure: event.event.failure,
        ),
      );
    });
    on<UnreadNotificationCountRequested>((event, emit) async {
      try {
        if (!isClosed) await _refreshCount(emit);
      } finally {
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
    on<NotificationsActionEvent>((event, emit) async {
      try {
        if (isClosed) return;
        switch (event) {
          case NotificationsRefreshRequested():
            await _load(emit, reset: true);
            if (!isClosed) await _refreshCount(emit);
          case NotificationsNextPageRequested():
            if (state.hasNext) await _load(emit, reset: false);
          case NotificationsFilterChanged():
            if (state.filter != event.filter) {
              emit(
                state.copyWith(
                  filter: event.filter,
                  items: const [],
                  page: 0,
                  total: 0,
                  loaded: false,
                  failure: null,
                ),
              );
              await _load(emit, reset: true);
            }
          case NotificationReadRequested():
            await _markRead(event.id, emit);
          case AllNotificationsReadRequested():
            await _markAllRead(emit);
          case NotificationsSynchronizationRequested():
            _syncDirty = false;
            if (!_realtimeActive) return;
            await _refreshCount(emit);
            if (!isClosed && _realtimeActive && _listVisible) {
              await _load(emit, reset: true);
            }
        }
      } finally {
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }

  final GetNotifications _getNotifications;
  final GetUnreadNotificationCount _getCount;
  final ReadNotification _read;
  final ReadAllNotifications _readAll;
  final _pending = <Type>{};
  int _countGeneration = 0;
  final WatchNotificationUpdates? _watchUpdates;
  final Duration pollInterval, reconciliationInterval, invalidationDelay;
  StreamSubscription<NotificationRealtimeEvent>? _realtime;
  Timer? _pollTimer, _syncTimer;
  Duration? _pollingInterval;
  bool _realtimeActive = false,
      _listVisible = false,
      _syncDirty = false,
      _syncQueued = false;
  final _recentEvents = <String>{};

  void setListVisible(bool value) {
    _listVisible = value;
  }

  void startRealtime() {
    if (isClosed || _realtimeActive || _watchUpdates == null) return;
    _realtimeActive = true;
    _realtime = _watchUpdates().listen(
      (event) {
        if (isClosed || !_realtimeActive) return;
        switch (event) {
          case NotificationRealtimeStatusChanged():
            add(NotificationRealtimeStatusReceived(event));
            if (event.status == NotificationRealtimeStatus.connected) {
              // Pub/Sub delivery is best effort, so also recover lost invalidations.
              _startPolling(reconciliationInterval);
            } else if (event.status ==
                    NotificationRealtimeStatus.reconnecting ||
                event.status == NotificationRealtimeStatus.disabled) {
              _startPolling();
            }
          case NotificationRealtimeReady():
            synchronize();
          case NotificationDataChanged():
            if (!_recentEvents.add(event.eventId)) return;
            if (_recentEvents.length > 128) {
              _recentEvents.remove(_recentEvents.first);
            }
            synchronize();
        }
      },
      onError: (Object _) {
        if (_realtimeActive && !isClosed) _startPolling();
      },
    );
  }

  void _startPolling([Duration? interval]) {
    final desired = interval ?? pollInterval;
    if (_pollTimer != null && _pollingInterval == desired) return;
    _pollTimer?.cancel();
    _pollingInterval = desired;
    _pollTimer = Timer.periodic(desired, (_) => synchronize());
  }

  void synchronize() {
    if (isClosed || !_realtimeActive) return;
    _syncDirty = true;
    _scheduleSynchronization();
  }

  void _scheduleSynchronization() {
    if (isClosed || !_realtimeActive || _syncQueued || _syncTimer != null) {
      return;
    }
    _syncTimer = Timer(invalidationDelay, () {
      _syncTimer = null;
      if (isClosed || !_realtimeActive) return;
      _syncQueued = true;
      final event = NotificationsSynchronizationRequested();
      add(event);
      event.completion.future.whenComplete(() {
        _syncQueued = false;
        if (_syncDirty && !isClosed && _realtimeActive) {
          _scheduleSynchronization();
        }
      });
    });
  }

  Future<void> pauseRealtime() async {
    _realtimeActive = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingInterval = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    final subscription = _realtime;
    _realtime = null;
    await subscription?.cancel();
  }

  @override
  Future<void> close() {
    final stopping = pauseRealtime();
    final closing = super.close();
    return Future.wait([stopping, closing]).then((_) {});
  }

  Future<void> dispatch(NotificationsEvent event) async {
    if (isClosed || !_pending.add(event.runtimeType)) return;
    try {
      add(event);
      await event.completion.future;
    } finally {
      _pending.remove(event.runtimeType);
    }
  }

  Future<void> retry() => dispatch(
    state.retryReset
        ? NotificationsRefreshRequested()
        : NotificationsNextPageRequested(),
  );

  AuthFailure _failure(Object error) => error is AuthFailure
      ? error
      : const AuthFailure(
          FailureKind.unexpected,
          'Chưa thể xử lý thông báo. Vui lòng thử lại.',
        );

  Future<void> _load(
    Emitter<NotificationsState> emit, {
    required bool reset,
  }) async {
    final page = reset ? 1 : state.page + 1;
    emit(state.copyWith(loading: true, failure: null, retryReset: reset));
    try {
      final result = await _getNotifications(
        filter: state.filter,
        page: page,
        limit: state.limit,
      );
      if (isClosed) return;
      if (result.page != page || result.limit != state.limit) {
        throw const AuthFailure(
          FailureKind.server,
          'Dữ liệu phân trang thông báo chưa hợp lệ.',
        );
      }
      final items = {
        if (!reset)
          for (final item in state.items) item.id: item,
      };
      for (final item in result.items) {
        items[item.id] = item;
      }
      final ordered = items.values.toList()
        ..sort((a, b) {
          final time = b.createdAt.compareTo(a.createdAt);
          return time == 0 ? b.id.compareTo(a.id) : time;
        });
      emit(
        state.copyWith(
          items: ordered,
          page: result.page,
          total: result.total,
          limit: result.limit,
          loaded: true,
          loading: false,
        ),
      );
    } on Object catch (error) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, failure: _failure(error)));
      }
    }
  }

  Future<void> _refreshCount(Emitter<NotificationsState> emit) async {
    final generation = ++_countGeneration;
    emit(state.copyWith(loadingCount: true, countFailure: null));
    try {
      final count = await _getCount();
      if (!isClosed && generation == _countGeneration) {
        emit(state.copyWith(unreadCount: count, loadingCount: false));
      }
    } on Object catch (error) {
      if (!isClosed && generation == _countGeneration) {
        emit(
          state.copyWith(loadingCount: false, countFailure: _failure(error)),
        );
      }
    }
  }

  Future<void> _markRead(String id, Emitter<NotificationsState> emit) async {
    final item = state.items.where((item) => item.id == id).firstOrNull;
    if (item == null || !item.isUnread) return;
    emit(state.copyWith(mutating: true, failure: null));
    AuthFailure? failure;
    try {
      final updated = await _read(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          items: state.items
              .map((item) => item.id == id ? updated : item)
              .toList(),
        ),
      );
    } on Object catch (error) {
      failure = _failure(error);
    }
    if (isClosed) return;
    // Removing unread rows shifts offset pagination; restart it before appending.
    if (state.filter == NotificationFilter.unread || failure != null) {
      await _load(emit, reset: true);
    }
    if (isClosed) return;
    await _refreshCount(emit);
    if (!isClosed) {
      emit(state.copyWith(mutating: false, failure: failure ?? state.failure));
    }
  }

  Future<void> _markAllRead(Emitter<NotificationsState> emit) async {
    if (!state.loaded ||
        (state.unreadCount == 0 && !state.items.any((item) => item.isUnread))) {
      return;
    }
    emit(state.copyWith(mutating: true, failure: null));
    AuthFailure? failure;
    try {
      await _readAll();
    } on Object catch (error) {
      failure = _failure(error);
    }
    if (isClosed) return;
    // Never set the badge from the affected-row count or stamp local readAt values:
    // notifications created after the backend's cutoff must remain unread.
    await _load(emit, reset: true);
    if (isClosed) return;
    await _refreshCount(emit);
    if (!isClosed) {
      emit(state.copyWith(mutating: false, failure: failure ?? state.failure));
    }
  }
}
