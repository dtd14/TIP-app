import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/utils/validators.dart';

void main() {
  test(
    'DTO password minimum and registration maximum are enforced without trimming',
    () {
      expect(Validators.loginPassword('1234567'), isNotNull);
      expect(Validators.loginPassword('12345678'), isNull);
      expect(Validators.password('x' * 129), isNotNull);
      expect(Validators.loginPassword('x' * 129), isNull);
      expect(Validators.password(' 123456 '), isNull);
    },
  );
  test('DTO text and phone limits match server', () {
    expect(Validators.limitedText('x' * 151, 'Họ và tên', 150), isNotNull);
    expect(Validators.limitedText('x' * 65, 'Tên đăng nhập', 64), isNotNull);
    expect(Validators.limitedText('x' * 64, 'Tên đăng nhập', 64), isNull);
    expect(Validators.phone('x' * 31), isNotNull);
    expect(Validators.phone(null), isNull);
  });
  test('OTP format matches VerifyOtpDto', () {
    expect(Validators.otp('123456'), isNull);
    expect(Validators.otp('12345'), isNotNull);
    expect(Validators.otp('12345a'), isNotNull);
  });
}
