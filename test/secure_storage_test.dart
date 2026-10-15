import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'support/auth_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'secure storage roundtrip persists credential only and clears it',
    () async {
      final storage = SecureSessionStorage(scope: 'test');
      await storage.write(testCredential);
      final restored = await storage.read();
      expect(restored!.kind, CredentialKind.bearer);
      expect(restored.value, 'test-only-token');
      expect(testCredential.toString(), isNot(contains('test-only-token')));
      await storage.clear();
      expect(await storage.read(), isNull);
    },
  );
  test('invalid persisted data is removed and treated as signed out', () async {
    FlutterSecureStorage.setMockInitialValues({
      'tip.session.v1.test': '{broken',
    });
    final storage = SecureSessionStorage(scope: 'test');
    expect(await storage.read(), isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'tip.session.v1.test'),
      isNull,
    );
  });
  test('credentials are isolated between backend origins', () async {
    final one = SecureSessionStorage(scope: 'one');
    final two = SecureSessionStorage(scope: 'two');
    await one.write(testCredential);
    expect(await two.read(), isNull);
  });
  test(
    'both rotated tokens survive storage without exposing them in text',
    () async {
      const pair = SessionCredential(
        kind: CredentialKind.bearer,
        value: 'test-access-only',
        refreshToken: 'test-refresh-only',
      );
      final storage = SecureSessionStorage(scope: 'pair');
      await storage.write(pair);
      final restored = await storage.read();
      expect(restored!.value, pair.value);
      expect(restored.refreshToken, pair.refreshToken);
      expect(pair.toString(), isNot(contains(pair.value)));
      expect(pair.toString(), isNot(contains(pair.refreshToken!)));
    },
  );
}
