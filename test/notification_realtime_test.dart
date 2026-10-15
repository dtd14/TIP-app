import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_realtime_remote_data_source.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_realtime_settings.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_socket.dart';
import 'package:tip_app/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:tip_app/features/notifications/domain/entities/notification_realtime_event.dart';
import 'nest_auth_remote_data_source_test.dart' show ControllerAdapter;
import 'support/auth_fakes.dart';
import 'support/nest_fixtures.dart' show body;

class FakeNotificationSocket implements NotificationSocket {
  final incoming = StreamController<Object?>();
  final frames = <String>[];
  bool closed = false;
  @override
  Future<void> ready = Future.value();
  @override
  int? closeCode;
  @override
  Stream<Object?> get messages => incoming.stream;
  @override
  void send(String text) => frames.add(text);
  void emit(Object? frame) =>
      incoming.add(frame is Map ? jsonEncode(frame) : frame);
  Future<void> serverClose(int code) async {
    closeCode = code;
    await incoming.close();
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!incoming.isClosed) await incoming.close();
  }
}

Future<void> eventually(bool Function() check) async {
  for (var attempt = 0; attempt < 200 && !check(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(check(), true);
}

void main() {
  late AppDependencies dependencies;
  late ControllerAdapter adapter;
  late NotificationRealtimeRemoteDataSource source;
  late List<FakeNotificationSocket> sockets;
  late List<(Uri, String?)> connections;
  setUp(() async {
    dependencies = AppDependencies.create(
      authRemote: FakeAuthRemote(),
      sessionStorage: MemorySessionStorage()..value = testCredential,
    );
    await dependencies.authRepository.getCurrentUser();
    adapter = ControllerAdapter()
      ..onRequest = (_) => body({
        'ticket': 'a' * 43,
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 45))
            .toUtc()
            .toIso8601String(),
      });
    dependencies.apiClient.dio.httpClientAdapter = adapter;
    sockets = [];
    connections = [];
    source = NotificationRealtimeRemoteDataSource(
      NotificationsRemoteDataSource(dependencies.apiClient),
      NotificationRealtimeSettings(
        uri: Uri.parse('wss://api.example.test/notifications/ws'),
        origin: 'https://app.example.test',
      ),
      (uri, origin) {
        connections.add((uri, origin));
        final socket = FakeNotificationSocket();
        sockets.add(socket);
        return socket;
      },
      initialRetry: const Duration(milliseconds: 10),
      maximumRetry: const Duration(milliseconds: 30),
      authenticationTimeout: const Duration(milliseconds: 100),
    );
  });
  tearDown(() async {
    await source.dispose();
    await dependencies.dispose();
  });

  test(
    'ticket uses Bearer REST; only the authenticate frame carries it',
    () async {
      final events = <NotificationRealtimeEvent>[];
      final subscription = source.watch().listen(events.add);
      addTearDown(subscription.cancel);
      await eventually(
        () => sockets.isNotEmpty && sockets.first.frames.isNotEmpty,
      );
      expect(adapter.requests.single.path, '/notifications/socket-ticket');
      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer test-only-token',
      );
      expect(adapter.requests.single.data, isNull);
      expect(connections.single, (
        Uri.parse('wss://api.example.test/notifications/ws'),
        'https://app.example.test',
      ));
      expect(connections.single.$1.hasQuery, false);
      expect(jsonDecode(sockets.first.frames.single), {
        'type': 'authenticate',
        'ticket': 'a' * 43,
      });
      sockets.first.emit({'type': 'notifications.ready'});
      sockets.first.emit({
        'type': 'notifications.changed',
        'eventId': 'event-1',
        'reason': 'read-all',
        'emittedAt': '2026-10-08T08:00:00Z',
      });
      await eventually(
        () => events.any((event) => event is NotificationDataChanged),
      );
      expect(
        events.whereType<NotificationDataChanged>().single.reason,
        NotificationChangeReason.readAll,
      );
      expect(sockets.first.frames, hasLength(1));
    },
  );

  test(
    '4401 reconnect fetches a new one-use ticket and authenticates again',
    () async {
      var tickets = 0;
      adapter.onRequest = (_) => body({
        'ticket': (++tickets == 1 ? 'a' : 'b') * 43,
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 45))
            .toUtc()
            .toIso8601String(),
      });
      final subscription = source.watch().listen((_) {});
      addTearDown(subscription.cancel);
      await eventually(
        () => sockets.isNotEmpty && sockets.first.frames.isNotEmpty,
      );
      sockets.first.emit({'type': 'notifications.ready'});
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await sockets.first.serverClose(4401);
      await eventually(
        () => sockets.length == 2 && sockets.last.frames.isNotEmpty,
      );
      expect(tickets, 2);
      expect(jsonDecode(sockets.last.frames.single)['ticket'], 'b' * 43);
      expect(sockets.first.closed, true);
    },
  );

  test(
    'REALTIME_DISABLED emits fallback once without opening or retrying a socket',
    () async {
      adapter.onRequest = (_) => body({
        'code': 'REALTIME_DISABLED',
        'message': 'Realtime disabled',
      }, status: 503);
      final statuses = <NotificationRealtimeStatus>[];
      final subscription = source.watch().listen((event) {
        if (event is NotificationRealtimeStatusChanged) {
          statuses.add(event.status);
        }
      });
      addTearDown(subscription.cancel);
      await eventually(
        () => statuses.contains(NotificationRealtimeStatus.disabled),
      );
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(adapter.requests, hasLength(1));
      expect(sockets, isEmpty);
    },
  );

  test('data before ready is rejected and never reaches the Bloc', () async {
    final events = <NotificationRealtimeEvent>[];
    final subscription = source.watch().listen(events.add);
    addTearDown(subscription.cancel);
    await eventually(
      () => sockets.isNotEmpty && sockets.first.frames.isNotEmpty,
    );
    sockets.first.emit({
      'type': 'notifications.changed',
      'eventId': 'event-1',
      'reason': 'created',
      'emittedAt': '2026-10-08T08:00:00Z',
    });
    await eventually(() => sockets.first.closed);
    expect(events.whereType<NotificationDataChanged>(), isEmpty);
    await subscription.cancel();
  });

  test(
    'cancellation during ticket issuance prevents a late connection',
    () async {
      final pending = Completer<ResponseBody>();
      adapter.onRequest = (_) => pending.future;
      final subscription = source.watch().listen((_) {});
      await eventually(() => adapter.requests.isNotEmpty);
      await subscription.cancel();
      pending.complete(
        body({
          'ticket': 'a' * 43,
          'expiresAt': DateTime.now()
              .add(const Duration(seconds: 45))
              .toUtc()
              .toIso8601String(),
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(sockets, isEmpty);
      expect(adapter.requests, hasLength(1));
    },
  );

  test('cancel after disconnect cancels pending reconnect', () async {
    final subscription = source.watch().listen((_) {});
    await eventually(
      () => sockets.isNotEmpty && sockets.first.frames.isNotEmpty,
    );
    await sockets.first.serverClose(1013);
    await subscription.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(sockets, hasLength(1));
    expect(adapter.requests, hasLength(1));
  });

  test(
    'an unacknowledged authentication attempt times out and closes',
    () async {
      final subscription = source.watch().listen((_) {});
      addTearDown(subscription.cancel);
      await eventually(
        () => sockets.isNotEmpty && sockets.first.frames.isNotEmpty,
      );
      await eventually(() => sockets.first.closed);
      await subscription.cancel();
    },
  );

  test(
    'native configuration requires an allowed Origin and exact WSS path',
    () {
      final api = Uri.parse('https://api.example.test');
      expect(
        NotificationRealtimeSettings.forOrigin(
          api,
          requiresOrigin: true,
        ).enabled,
        false,
      );
      expect(
        NotificationRealtimeSettings.forOrigin(
          api,
          requiresOrigin: false,
        ).enabled,
        true,
      );
      final settings = NotificationRealtimeSettings.forOrigin(
        api,
        requiresOrigin: true,
        nativeOrigin: 'https://app.example.test',
      );
      expect(settings.enabled, true);
      expect(
        settings.uri.toString(),
        'wss://api.example.test/notifications/ws',
      );
      expect(
        () => NotificationRealtimeSettings.forOrigin(
          api,
          requiresOrigin: false,
          socketUrl: 'wss://api.example.test/notifications/ws?ticket=secret',
        ),
        throwsArgumentError,
      );
    },
  );
}
