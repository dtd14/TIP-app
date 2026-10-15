import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local credential format, NOT a backend response DTO.
/// The verified API adapter must select the supported session mechanism.
enum CredentialKind { bearer, cookie }

class SessionCredential {
  const SessionCredential({
    required this.kind,
    required this.value,
    this.refreshToken,
  });
  final CredentialKind kind;
  final String value;
  final String? refreshToken;
  bool get isValid =>
      value.isNotEmpty &&
      !value.contains('\r') &&
      !value.contains('\n') &&
      (refreshToken == null ||
          (kind == CredentialKind.bearer &&
              refreshToken!.isNotEmpty &&
              !refreshToken!.contains('\r') &&
              !refreshToken!.contains('\n')));
  String encode() => jsonEncode({
    'kind': kind.name,
    'value': value,
    if (refreshToken != null) 'refreshToken': refreshToken,
  });
  static SessionCredential decode(String encoded) {
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final kind = CredentialKind.values.byName(json['kind'] as String);
    final value = json['value'] as String;
    final credential = SessionCredential(
      kind: kind,
      value: value,
      refreshToken: json['refreshToken'] as String?,
    );
    if (!credential.isValid) {
      throw const FormatException('Invalid session credential');
    }
    return credential;
  }

  @override
  String toString() => 'SessionCredential(redacted)';
}

abstract interface class SessionStorage {
  Future<SessionCredential?> read();
  Future<void> write(SessionCredential credential);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage, required String scope})
    : _storage = storage ?? const FlutterSecureStorage(),
      _key = 'tip.session.v1.$scope';
  final FlutterSecureStorage _storage;
  final String _key;
  @override
  Future<SessionCredential?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      return SessionCredential.decode(value);
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(SessionCredential credential) =>
      _storage.write(key: _key, value: credential.encode());
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
