import 'package:dio/dio.dart';
import 'package:tip_app/core/network/api_client.dart';
import 'package:tip_app/core/network/api_endpoints.dart';

class NotificationsRemoteDataSource {
  const NotificationsRemoteDataSource(this.client);
  final ApiClient client;
  Future<Object?> socketTicket({CancelToken? cancelToken}) async =>
      (await client.dio.post<Object?>(
        '${ApiEndpoints.notifications}/socket-ticket',
        options: _authenticated,
        cancelToken: cancelToken,
      )).data;
  Options get _authenticated =>
      Options(extra: {'requiresAuth': true, 'requiresBearerAuth': true});

  Future<Object?> list({
    required String filter,
    required int page,
    required int limit,
  }) async => (await client.dio.get<Object?>(
    ApiEndpoints.notifications,
    queryParameters: {'filter': filter, 'page': page, 'limit': limit},
    options: _authenticated,
  )).data;

  Future<Object?> unreadCount() async => (await client.dio.get<Object?>(
    '${ApiEndpoints.notifications}/unread-count',
    options: _authenticated,
  )).data;

  Future<Object?> read(String id) async => (await client.dio.patch<Object?>(
    '${ApiEndpoints.notifications}/${Uri.encodeComponent(id)}/read',
    options: _authenticated,
  )).data;

  Future<Object?> readAll() async => (await client.dio.patch<Object?>(
    '${ApiEndpoints.notifications}/read-all',
    options: _authenticated,
  )).data;
}
