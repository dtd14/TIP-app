/// Client checks matching LoginDto and RegisterUserDto.
abstract final class Validators {
  static String? requiredText(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Vui lòng nhập $label.' : null;
  static String? limitedText(String? value, String label, int max) {
    final required = requiredText(value, label);
    if (required != null) return required;
    return value!.trim().runes.length > max
        ? '$label tối đa $max ký tự.'
        : null;
  }

  static String? loginPassword(String? value) =>
      password(value, maxLength: null);
  static String? password(String? value, {int? maxLength = 128}) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (value.runes.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự.';
    if (maxLength != null && value.runes.length > maxLength) {
      return 'Mật khẩu tối đa $maxLength ký tự.';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value, 'email');
    if (required != null) return required;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())) {
      return 'Email không hợp lệ.';
    }
    return null;
  }

  static String? phone(String? value) =>
      value != null && value.trim().runes.length > 30
      ? 'Số điện thoại tối đa 30 ký tự.'
      : null;
  static String? otp(String? value) =>
      value != null && RegExp(r'^\d{6}$').hasMatch(value)
      ? null
      : 'Mã xác minh phải gồm đúng 6 chữ số.';
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu.';
    return value == password ? null : 'Mật khẩu xác nhận không khớp.';
  }
}
