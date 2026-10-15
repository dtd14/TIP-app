import 'package:tip_app/core/domain/entities/page_slice.dart';

abstract final class JsonDecoder {
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid object');
    }
    return value;
  }

  static String text(Map<String, dynamic> value, String key) {
    final field = value[key];
    if (field is! String || field.trim().isEmpty) {
      throw FormatException('Invalid $key');
    }
    return field;
  }

  static String? optionalText(Map<String, dynamic> value, String key) {
    final field = value[key];
    if (field == null || field == '') return null;
    if (field is! String) throw FormatException('Invalid $key');
    return field;
  }

  static DateTime date(Map<String, dynamic> value, String key) =>
      DateTime.parse(text(value, key));
  static DateTime? optionalDate(Map<String, dynamic> value, String key) =>
      value[key] == null ? null : date(value, key);

  static int? positiveInteger(Map<String, dynamic> value, String key) {
    final field = value[key];
    if (field == null) return null;
    if (field is! int || field < 1) throw FormatException('Invalid $key');
    return field;
  }

  static PageSlice<T> page<T>(Object? value, T Function(Object?) decode) {
    final data = object(value);
    final items = data['data'],
        total = data['total'],
        page = data['page'],
        limit = data['limit'];
    if (items is! List ||
        total is! int ||
        total < 0 ||
        page is! int ||
        page < 1 ||
        limit is! int ||
        limit < 1) {
      throw const FormatException('Invalid pagination');
    }
    return PageSlice(
      items: List.unmodifiable(items.map(decode)),
      total: total,
      page: page,
      limit: limit,
    );
  }
}
