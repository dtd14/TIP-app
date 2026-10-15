import 'package:web_socket_channel/io.dart';
import 'notification_channel_socket.dart';
import 'notification_socket.dart';

bool get notificationSocketRequiresOrigin => true;
NotificationSocket connectNotificationSocket(Uri uri, String? origin) =>
    NotificationChannelSocket(
      IOWebSocketChannel.connect(
        uri,
        headers: {'Origin': origin},
        connectTimeout: const Duration(seconds: 10),
      ),
    );
