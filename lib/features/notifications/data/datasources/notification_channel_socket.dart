import 'package:web_socket_channel/web_socket_channel.dart';
import 'notification_socket.dart';

class NotificationChannelSocket implements NotificationSocket {
  NotificationChannelSocket(this.channel);
  final WebSocketChannel channel;
  @override
  Future<void> get ready => channel.ready;
  @override
  Stream<Object?> get messages => channel.stream;
  @override
  int? get closeCode => channel.closeCode;
  @override
  void send(String text) => channel.sink.add(text);
  @override
  Future<void> close() async {
    await channel.sink.close(1000, 'Session paused');
  }
}
