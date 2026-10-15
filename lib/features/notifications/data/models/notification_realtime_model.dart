import 'dart:convert';
import 'package:tip_app/core/data/json_decoder.dart';
import '../../domain/entities/notification_realtime_event.dart';

abstract final class NotificationRealtimeModel {
  static NotificationRealtimeEvent decode(Object? frame) {
    if (frame is! String || frame.length > 4096) {
      throw const FormatException('Invalid notification socket frame');
    }
    final data = JsonDecoder.object(jsonDecode(frame));
    if (data['type'] == 'notifications.ready') {
      return const NotificationRealtimeReady();
    }
    if (data['type'] != 'notifications.changed') {
      throw const FormatException('Unexpected notification socket frame');
    }
    final reason = switch (data['reason']) {
      'created' => NotificationChangeReason.created,
      'read' => NotificationChangeReason.read,
      'read-all' => NotificationChangeReason.readAll,
      _ => throw const FormatException('Invalid notification change reason'),
    };
    return NotificationDataChanged(
      eventId: JsonDecoder.text(data, 'eventId'),
      reason: reason,
      emittedAt: JsonDecoder.date(data, 'emittedAt'),
    );
  }
}
