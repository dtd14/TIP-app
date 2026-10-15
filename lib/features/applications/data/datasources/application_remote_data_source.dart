import 'package:dio/dio.dart';
import 'package:tip_app/core/network/api_client.dart';
import 'package:tip_app/core/network/api_endpoints.dart';

class ApplicationRemoteDataSource {
  const ApplicationRemoteDataSource(this.client);
  final ApiClient client;
  Options get _authenticated =>
      Options(extra: {'requiresAuth': true, 'requiresBearerAuth': true});
  Future<Object?> applications({
    int page = 1,
    int limit = 20,
    String? status,
  }) async => (await client.dio.get<Object?>(
    ApiEndpoints.applications,
    queryParameters: {'page': page, 'limit': limit, 'status': ?status},
    options: _authenticated,
  )).data;

  Future<Object?> apply(String id) async => (await client.dio.post<Object?>(
    ApiEndpoints.applications,
    data: {'opportunityId': id},
    options: _authenticated,
  )).data;

  Future<Object?> application(String id) async =>
      (await client.dio.get<Object?>(
        '${ApiEndpoints.applications}/${Uri.encodeComponent(id)}',
        options: _authenticated,
      )).data;
  Future<Object?> withdraw(String id) async => (await client.dio.patch<Object?>(
    '${ApiEndpoints.applications}/${Uri.encodeComponent(id)}/withdraw',
    options: _authenticated,
  )).data;
}
