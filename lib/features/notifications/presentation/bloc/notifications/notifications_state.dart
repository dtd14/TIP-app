import 'package:tip_app/core/errors/failures.dart';
import '../../../domain/entities/app_notification.dart';
import '../../../domain/entities/notification_realtime_event.dart';

const _unchanged = Object();

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.filter = NotificationFilter.all,
    this.page = 0,
    this.total = 0,
    this.limit = 20,
    this.loading = false,
    this.loadingCount = false,
    this.mutating = false,
    this.loaded = false,
    this.retryReset = true,
    this.unreadCount,
    this.failure,
    this.countFailure,
    this.realtimeStatus = NotificationRealtimeStatus.idle,
    this.realtimeFailure,
  });
  final List<AppNotification> items;
  final NotificationFilter filter;
  final int page, total, limit;
  final int? unreadCount;
  final bool loading, loadingCount, mutating, loaded, retryReset;
  final AuthFailure? failure, countFailure;
  final NotificationRealtimeStatus realtimeStatus;
  final AuthFailure? realtimeFailure;
  bool get hasNext => page > 0 && page * limit < total;
  bool get busy => loading || mutating;

  NotificationsState copyWith({
    List<AppNotification>? items,
    NotificationFilter? filter,
    int? page,
    int? total,
    int? limit,
    bool? loading,
    bool? loadingCount,
    bool? mutating,
    bool? loaded,
    bool? retryReset,
    Object? unreadCount = _unchanged,
    Object? failure = _unchanged,
    Object? countFailure = _unchanged,
    NotificationRealtimeStatus? realtimeStatus,
    Object? realtimeFailure = _unchanged,
  }) => NotificationsState(
    items: items == null ? this.items : List.unmodifiable(items),
    filter: filter ?? this.filter,
    page: page ?? this.page,
    total: total ?? this.total,
    limit: limit ?? this.limit,
    loading: loading ?? this.loading,
    loadingCount: loadingCount ?? this.loadingCount,
    mutating: mutating ?? this.mutating,
    loaded: loaded ?? this.loaded,
    retryReset: retryReset ?? this.retryReset,
    unreadCount: identical(unreadCount, _unchanged)
        ? this.unreadCount
        : unreadCount as int?,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as AuthFailure?,
    countFailure: identical(countFailure, _unchanged)
        ? this.countFailure
        : countFailure as AuthFailure?,
    realtimeStatus: realtimeStatus ?? this.realtimeStatus,
    realtimeFailure: identical(realtimeFailure, _unchanged)
        ? this.realtimeFailure
        : realtimeFailure as AuthFailure?,
  );
}
