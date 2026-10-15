import 'package:dio/dio.dart';
import 'package:tip_app/core/network/api_client.dart';
import 'package:tip_app/core/network/api_endpoints.dart';

class OpportunityRemoteDataSource {
  const OpportunityRemoteDataSource(this.client);
  final ApiClient client;
  Options get _authenticated =>
      Options(extra: {'requiresAuth': true, 'requiresBearerAuth': true});
  Future<Object?> opportunities({int page = 1}) async =>
      (await client.dio.get<Object?>(
        ApiEndpoints.publicOpportunities,
        queryParameters: {'page': page, 'limit': 12},
      )).data;

  Future<Object?> opportunity(String id) async =>
      (await client.dio.get<Object?>(
        '${ApiEndpoints.opportunities}/${Uri.encodeComponent(id)}',
        options: _authenticated,
      )).data;

  Future<Object?> company(String id) async => (await client.dio.get<Object?>(
    '${ApiEndpoints.companies}/${Uri.encodeComponent(id)}',
  )).data;

  Future<Object?> availableOpportunities() async =>
      (await client.dio.get<Object?>(
        ApiEndpoints.opportunities,
        options: _authenticated,
      )).data;
}
