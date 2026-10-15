import 'dart:convert';
import 'package:dio/dio.dart';

const tokenPair = {
  'accessToken': 'test-access',
  'refreshToken': 'test-refresh',
};
const rotatedTokenPair = {
  'accessToken': 'test-access-new',
  'refreshToken': 'test-refresh-new',
};
ResponseBody body(Object? payload, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
Map<String, Object?> registrationResponse({required bool otpSent}) => {
  'message': 'Registration successful. Verify your email before signing in.',
  'otpSent': otpSent,
  'account': {
    'id': 'account-1',
    'email': 'student@example.com',
    'schoolUser': null,
  },
};
Map<String, Object?> expiredResponse() => {
  'statusCode': 401,
  'message': 'Unauthorized',
};
