import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_realtime_remote_data_source.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_realtime_settings.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_socket_connector_io.dart';
import 'package:tip_app/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:tip_app/features/notifications/domain/entities/notification_realtime_event.dart';
import 'nest_auth_remote_data_source_test.dart' show ControllerAdapter;
import 'support/auth_fakes.dart';
import 'support/nest_fixtures.dart' show body;

void main() {
  test(
    'native connector sends allowed Origin and authenticates over a real local WebSocket',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<(String?, String?, Object?)>();
      final serverRequests = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((frame) {
          if (!received.isCompleted) {
            received.complete((
              request.uri.toString(),
              request.headers.value('origin'),
              jsonDecode(frame as String),
            ));
          }
          socket.add(jsonEncode({'type': 'notifications.ready'}));
          socket.add(
            jsonEncode({
              'type': 'notifications.changed',
              'eventId': 'local-event',
              'reason': 'created',
              'emittedAt': '2026-10-08T08:00:00Z',
            }),
          );
        });
      });
      addTearDown(serverRequests.cancel);
      final dependencies = AppDependencies.create(
        authRemote: FakeAuthRemote(),
        sessionStorage: MemorySessionStorage()..value = testCredential,
      );
      addTearDown(dependencies.dispose);
      await dependencies.authRepository.getCurrentUser();
      dependencies.apiClient.dio.httpClientAdapter = ControllerAdapter()
        ..onRequest = (_) => body({
          'ticket': 'a' * 43,
          'expiresAt': DateTime.now()
              .add(const Duration(seconds: 45))
              .toUtc()
              .toIso8601String(),
        });
      final source = NotificationRealtimeRemoteDataSource(
        NotificationsRemoteDataSource(dependencies.apiClient),
        NotificationRealtimeSettings(
          uri: Uri.parse('ws://127.0.0.1:${server.port}/notifications/ws'),
          origin: 'https://allowed.example.test',
        ),
        connectNotificationSocket,
      );
      addTearDown(source.dispose);
      final changed = Completer<NotificationDataChanged>();
      final subscription = source.watch().listen((event) {
        if (event is NotificationDataChanged && !changed.isCompleted) {
          changed.complete(event);
        }
      });
      addTearDown(subscription.cancel);
      final frame = await received.future.timeout(const Duration(seconds: 3));
      expect(frame.$1, '/notifications/ws');
      expect(frame.$2, 'https://allowed.example.test');
      expect(frame.$3, {'type': 'authenticate', 'ticket': 'a' * 43});
      expect(
        (await changed.future.timeout(const Duration(seconds: 3))).eventId,
        'local-event',
      );
    },
  );
}
