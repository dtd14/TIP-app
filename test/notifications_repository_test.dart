import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/notifications/domain/entities/app_notification.dart';
import 'nest_auth_remote_data_source_test.dart' show ControllerAdapter;
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart' show pageFixture;
import 'support/nest_fixtures.dart' show body;
import 'support/notification_fakes.dart';

void main() {
  late AppDependencies dependencies;
  late ControllerAdapter adapter;
  setUp(() async {
    dependencies = AppDependencies.create(
      authRemote: FakeAuthRemote(),
      sessionStorage: MemorySessionStorage()..value = testCredential,
    );
    await dependencies.authRepository.getCurrentUser();
    adapter = ControllerAdapter();
    dependencies.apiClient.dio.httpClientAdapter = adapter;
  });
  tearDown(() => dependencies.dispose());

  test('list uses exact DTO query and protected Bearer request', () async {
    adapter.response = pageFixture([notificationJson()], page: 2, total: 21);
    final page = await dependencies.notificationsRepository.list(
      filter: NotificationFilter.unread,
      page: 2,
    );
    final request = adapter.requests.single;
    expect(request.path, '/notifications');
    expect(request.method, 'GET');
    expect(request.queryParameters, {
      'filter': 'unread',
      'page': 2,
      'limit': 20,
    });
    expect(request.headers['Authorization'], 'Bearer test-only-token');
    expect(page.items.single.isUnread, true);
    expect(page.total, 21);
    expect(page.hasNext, false);
  });

  test(
    'unread count and read-all affected count use different routes',
    () async {
      adapter.onRequest = (request) =>
          body({'count': request.path.endsWith('read-all') ? 12 : 3});
      expect(await dependencies.notificationsRepository.unreadCount(), 3);
      expect(await dependencies.notificationsRepository.readAll(), 12);
      expect(
        adapter.requests.map((request) => (request.method, request.path)),
        [
          ('GET', '/notifications/unread-count'),
          ('PATCH', '/notifications/read-all'),
        ],
      );
      expect(adapter.requests.every((request) => request.data == null), true);
    },
  );

  test(
    'read verifies the response identity and server read timestamp',
    () async {
      adapter.response = notificationJson(read: true);
      final item = await dependencies.notificationsRepository.read(
        notificationId,
      );
      expect(item.readAt, DateTime.utc(2026, 10, 8, 9));
      expect(
        adapter.requests.single.path,
        '/notifications/$notificationId/read',
      );
      expect(adapter.requests.single.method, 'PATCH');
      adapter.response = notificationJson(id: 'different', read: true);
      await expectLater(
        dependencies.notificationsRepository.read(notificationId),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.kind,
            'kind',
            FailureKind.server,
          ),
        ),
      );
    },
  );

  test('malformed count and unread filter responses fail safely', () async {
    adapter.response = {'count': -1};
    await expectLater(
      dependencies.notificationsRepository.unreadCount(),
      throwsA(isA<AuthFailure>()),
    );
    adapter.response = pageFixture([notificationJson(read: true)]);
    await expectLater(
      dependencies.notificationsRepository.list(
        filter: NotificationFilter.unread,
      ),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('query validation follows DTO bounds before making requests', () async {
    for (final args in [(0, 20), (100001, 20), (1, 0), (1, 101)]) {
      await expectLater(
        dependencies.notificationsRepository.list(
          page: args.$1,
          limit: args.$2,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.kind,
            'kind',
            FailureKind.validation,
          ),
        ),
      );
    }
    expect(adapter.requests, isEmpty);
  });
}
