abstract final class AppConfig {
  static const notificationsSocketUrl = String.fromEnvironment(
    'TIP_NOTIFICATIONS_WS_URL',
  );
  static const notificationsOrigin = String.fromEnvironment(
    'TIP_NOTIFICATIONS_ORIGIN',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'TIP_API_BASE_URL',
    defaultValue: 'https://tip-web-portal-api.vercel.app',
  );

  // Direct client routes live at the origin root, without an /api prefix.
  // ORIGIN_SECRET belongs only on the server and must never be bundled here.
}
