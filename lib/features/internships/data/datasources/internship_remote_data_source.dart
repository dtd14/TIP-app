import 'package:dio/dio.dart';
import 'package:tip_app/core/network/api_client.dart';
import 'package:tip_app/core/network/api_endpoints.dart';

class InternshipRemoteDataSource {
  const InternshipRemoteDataSource(this.client);
  final ApiClient client;
  Options get _authenticated =>
      Options(extra: {'requiresAuth': true, 'requiresBearerAuth': true});
  Future<Object?> placements(String status) async =>
      (await client.dio.get<Object?>(
        ApiEndpoints.placements,
        queryParameters: {'page': 1, 'limit': 1, 'status': status},
        options: _authenticated,
      )).data;

  Future<Object?> internshipPeriod(String id) async =>
      (await client.dio.get<Object?>(
        '${ApiEndpoints.internshipPeriods}/${Uri.encodeComponent(id)}',
        options: _authenticated,
      )).data;
  Future<Object?> placementList({int page = 1, String? registrationId}) async =>
      (await client.dio.get<Object?>(
        ApiEndpoints.placements,
        queryParameters: {
          'page': page,
          'limit': 20,
          'studentInternshipId': ?registrationId,
        },
        options: _authenticated,
      )).data;
  Future<Object?> placementDetail(String id) async =>
      (await client.dio.get<Object?>(
        '${ApiEndpoints.placements}/${Uri.encodeComponent(id)}',
        options: _authenticated,
      )).data;
}
