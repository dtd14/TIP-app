import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:tip_app/core/data/api_request.dart';
import 'package:tip_app/core/errors/failures.dart';
import '../../domain/entities/notification_realtime_event.dart';
import '../models/notification_realtime_model.dart';
import '../models/notification_socket_ticket.dart';
import 'notifications_remote_data_source.dart';
import 'notification_socket.dart';
import 'notification_realtime_settings.dart';

class NotificationRealtimeDisabled implements Exception {}

class NotificationRealtimeRemoteDataSource {
  NotificationRealtimeRemoteDataSource(
    this.remote,
    this.settings,
    this.connect, {
    this.now = DateTime.now,
    this.initialRetry = const Duration(seconds: 2),
    this.maximumRetry = const Duration(seconds: 60),
    this.authenticationTimeout = const Duration(seconds: 4),
  });
  final NotificationsRemoteDataSource remote;
  final NotificationRealtimeSettings settings;
  final NotificationSocketFactory connect;
  final DateTime Function() now;
  final Duration initialRetry, maximumRetry, authenticationTimeout;
  final _clients = <_NotificationConnection>{};
  bool _disposed = false;

  Stream<NotificationRealtimeEvent> watch() {
    if (_disposed) return const Stream.empty();
    late final _NotificationConnection connection;
    connection = _NotificationConnection(
      this,
      () => _clients.remove(connection),
    );
    _clients.add(connection);
    return connection.events;
  }

  Future<NotificationSocketTicket> ticket(CancelToken cancelToken) async {
    try {
      final response = await remote.socketTicket(cancelToken: cancelToken);
      return apiRequest(
        () async => NotificationSocketTicket.fromJson(response),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      if (error.response?.statusCode == 503 &&
          data is Map &&
          data['code'] == 'REALTIME_DISABLED') {
        throw NotificationRealtimeDisabled();
      }
      return apiRequest(() => Future<NotificationSocketTicket>.error(error));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await Future.wait(_clients.toList().map((client) => client.stop()));
    _clients.clear();
  }
}

class _NotificationConnection {
  _NotificationConnection(this.source, this.onStop) {
    _events = StreamController<NotificationRealtimeEvent>(
      onListen: _start,
      onCancel: stop,
    );
  }
  final NotificationRealtimeRemoteDataSource source;
  final void Function() onStop;
  late final StreamController<NotificationRealtimeEvent> _events;
  Stream<NotificationRealtimeEvent> get events => _events.stream;
  NotificationSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  CancelToken? _ticketCancel;
  Timer? _retry, _authTimer;
  int _generation = 0, _attempt = 0;
  bool _active = true, _sentAuthentication = false, _authenticated = false;
  bool _valid(int generation) => _active && generation == _generation;

  void _emit(NotificationRealtimeEvent event) {
    if (_active && !_events.isClosed) _events.add(event);
  }

  void _start() {
    if (!source.settings.enabled) {
      _emit(
        const NotificationRealtimeStatusChanged(
          NotificationRealtimeStatus.disabled,
        ),
      );
      unawaited(_events.close());
      return;
    }
    unawaited(_connect());
  }

  Future<void> _connect() async {
    if (!_active) return;
    final generation = ++_generation;
    _sentAuthentication = false;
    _authenticated = false;
    _emit(
      NotificationRealtimeStatusChanged(
        _attempt == 0
            ? NotificationRealtimeStatus.connecting
            : NotificationRealtimeStatus.reconnecting,
      ),
    );
    final cancelToken = CancelToken();
    _ticketCancel = cancelToken;
    try {
      final ticket = await source.ticket(cancelToken);
      if (!_valid(generation)) return;
      if (!ticket.expiresAt.isAfter(source.now())) {
        throw const FormatException('Expired notification ticket');
      }
      final socket = source.connect(
        source.settings.uri,
        source.settings.origin,
      );
      _socket = socket;
      _subscription = socket.messages.listen(
        (frame) => _message(frame, generation),
        onError: (Object _) => _lost(generation),
        onDone: () => _lost(generation),
        cancelOnError: true,
      );
      await socket.ready.timeout(const Duration(seconds: 10));
      if (!_valid(generation)) return;
      if (!ticket.expiresAt.isAfter(source.now())) {
        throw const FormatException('Expired notification ticket');
      }
      _sentAuthentication = true;
      socket.send(jsonEncode({'type': 'authenticate', 'ticket': ticket.value}));
      _authTimer = Timer(source.authenticationTimeout, () => _lost(generation));
    } on NotificationRealtimeDisabled {
      if (!_valid(generation)) return;
      _emit(
        const NotificationRealtimeStatusChanged(
          NotificationRealtimeStatus.disabled,
        ),
      );
      unawaited(_events.close());
    } on Object catch (error) {
      if (!_valid(generation)) return;
      _lost(generation, failure: error is AuthFailure ? error : null);
    }
  }

  void _message(Object? raw, int generation) {
    if (!_valid(generation)) return;
    try {
      final frame = NotificationRealtimeModel.decode(raw);
      switch (frame) {
        case NotificationRealtimeReady():
          if (!_sentAuthentication || _authenticated) {
            throw const FormatException('Unexpected ready frame');
          }
          _authenticated = true;
          _attempt = 0;
          _authTimer?.cancel();
          _emit(
            const NotificationRealtimeStatusChanged(
              NotificationRealtimeStatus.connected,
            ),
          );
          _emit(frame);
        case NotificationDataChanged():
          if (!_authenticated) {
            throw const FormatException('Notification before authentication');
          }
          _emit(frame);
        case NotificationRealtimeStatusChanged():
          throw const FormatException('Unexpected server status frame');
      }
    } on Object {
      _lost(generation);
    }
  }

  void _lost(int generation, {AuthFailure? failure}) {
    if (!_valid(generation)) return;
    _generation++;
    _authTimer?.cancel();
    _ticketCancel?.cancel();
    final socket = _socket;
    final subscription = _subscription;
    _socket = null;
    _subscription = null;
    if (subscription != null) unawaited(_cancel(subscription));
    if (socket != null) unawaited(_close(socket));
    _emit(
      NotificationRealtimeStatusChanged(
        NotificationRealtimeStatus.reconnecting,
        failure: failure,
      ),
    );
    final multiplier = 1 << (_attempt > 5 ? 5 : _attempt);
    final delay = failure?.kind == FailureKind.rateLimited
        ? const Duration(seconds: 60)
        : Duration(
            milliseconds: (source.initialRetry.inMilliseconds * multiplier)
                .clamp(
                  source.initialRetry.inMilliseconds,
                  source.maximumRetry.inMilliseconds,
                ),
          );
    _attempt++;
    _retry?.cancel();
    _retry = Timer(delay, () => unawaited(_connect()));
  }

  Future<void> _close(NotificationSocket socket) async {
    try {
      await socket.close().timeout(const Duration(seconds: 2));
    } on Object {
      /* Transport is already closed. */
    }
  }

  Future<void> _cancel(StreamSubscription<Object?> subscription) async {
    try {
      await subscription.cancel();
    } on Object {
      /* Still close the transport below. */
    }
  }

  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    _generation++;
    _retry?.cancel();
    _authTimer?.cancel();
    _ticketCancel?.cancel();
    final subscription = _subscription;
    final socket = _socket;
    _subscription = null;
    _socket = null;
    if (subscription != null) await _cancel(subscription);
    if (socket != null) await _close(socket);
    onStop();
    if (!_events.isClosed) unawaited(_events.close());
  }
}
