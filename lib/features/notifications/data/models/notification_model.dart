import 'package:tip_app/core/data/json_decoder.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import '../../domain/entities/app_notification.dart';

abstract final class NotificationModel {
  static AppNotification fromJson(Object? value) {
    final data = JsonDecoder.object(value);
    String string(String key) {
      final field = data[key];
      if (field is! String) throw FormatException('Invalid notification $key');
      return field;
    }

    if (!data.containsKey('readAt')) {
      throw const FormatException('Missing notification readAt');
    }
    return AppNotification(
      id: JsonDecoder.text(data, 'id'),
      type: string('type'),
      title: string('title'),
      body: string('body'),
      entityType: string('entityType'),
      entityId: string('entityId'),
      createdAt: JsonDecoder.date(data, 'createdAt'),
      readAt: JsonDecoder.optionalDate(data, 'readAt'),
    );
  }

  static PageSlice<AppNotification> page(Object? value) {
    final result = JsonDecoder.page(value, fromJson);
    if (result.limit > 100 || result.items.length > result.limit) {
      throw const FormatException('Invalid notification page size');
    }
    return result;
  }

  static int count(Object? value) {
    final count = JsonDecoder.object(value)['count'];
    if (count is! int || count < 0) {
      throw const FormatException('Invalid notification count');
    }
    return count;
  }
}
