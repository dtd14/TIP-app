import 'package:tip_app/core/data/json_decoder.dart';

class NotificationSocketTicket {
  const NotificationSocketTicket({
    required this.value,
    required this.expiresAt,
  });
  factory NotificationSocketTicket.fromJson(Object? value) {
    final data = JsonDecoder.object(value);
    final ticket = JsonDecoder.text(data, 'ticket');
    if (!RegExp(r'^[\w-]{43}$').hasMatch(ticket)) {
      throw const FormatException('Invalid notification ticket');
    }
    return NotificationSocketTicket(
      value: ticket,
      expiresAt: JsonDecoder.date(data, 'expiresAt'),
    );
  }
  final String value;
  final DateTime expiresAt;
  @override
  String toString() => 'NotificationSocketTicket(redacted)';
}
