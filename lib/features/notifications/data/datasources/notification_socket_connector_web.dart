import 'package:web_socket_channel/html.dart';
import 'notification_channel_socket.dart';
import 'notification_socket.dart';

bool get notificationSocketRequiresOrigin => false;
NotificationSocket connectNotificationSocket(Uri uri, String? origin) =>
    NotificationChannelSocket(HtmlWebSocketChannel.connect(uri));
