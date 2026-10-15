class NotificationRealtimeSettings {
  const NotificationRealtimeSettings({
    required this.uri,
    this.origin,
    this.enabled = true,
  });
  factory NotificationRealtimeSettings.forOrigin(
    Uri apiOrigin, {
    String socketUrl = '',
    String nativeOrigin = '',
    required bool requiresOrigin,
  }) {
    final uri = socketUrl.isEmpty
        ? apiOrigin.replace(scheme: 'wss', path: '/notifications/ws')
        : Uri.parse(socketUrl);
    if (uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.path != '/notifications/ws' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError(
        'TIP_NOTIFICATIONS_WS_URL must be a WSS URL ending in /notifications/ws without credentials or query parameters.',
      );
    }
    String? origin;
    if (nativeOrigin.isNotEmpty) {
      final parsed = Uri.parse(nativeOrigin);
      if (!{'https', 'http'}.contains(parsed.scheme) ||
          parsed.host.isEmpty ||
          parsed.userInfo.isNotEmpty ||
          (parsed.path.isNotEmpty && parsed.path != '/') ||
          parsed.hasQuery ||
          parsed.hasFragment) {
        throw ArgumentError(
          'TIP_NOTIFICATIONS_ORIGIN must be an HTTP(S) origin.',
        );
      }
      origin = parsed.origin;
    }
    return NotificationRealtimeSettings(
      uri: uri,
      origin: origin,
      enabled: !requiresOrigin || origin != null,
    );
  }
  final Uri uri;
  final String? origin;
  final bool enabled;
}
