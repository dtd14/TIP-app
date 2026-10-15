import 'package:dio/dio.dart';
import 'package:tip_app/core/network/auth_interceptor.dart';

class ApiClient {
  ApiClient({required String baseUrl, required AuthInterceptor authInterceptor})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          followRedirects: false,
          // Dio infers application/json for Map bodies and generates the
          // multipart boundary for FormData. Do not force a global Content-Type.
          headers: {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(authInterceptor);
  }
  final Dio dio;
  void close() => dio.close(force: true);
}
