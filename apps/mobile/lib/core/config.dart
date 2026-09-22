/// Build-time configuration. The app talks ONLY to the API on our NAS — never to a database or MinIO directly.
///   flutter run --dart-define=API_URL=https://api.example.uz
/// Android emulator reaches the host at 10.0.2.2; iOS simulator at localhost.
class AppConfig {
  const AppConfig._();
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

  /// Yandex MapKit key (owner action, docs/YANDEX-MAPS.md, D-026) — the SUPER_ADMIN/ADMIN/MANAGER map (M2 §14).
  static const String yandexMapKitKey = String.fromEnvironment('YANDEX_MAPKIT_KEY');

  static String get root => apiUrl.replaceAll(RegExp(r'/+$'), '');
  static String get apiBase => '$root/v1';
}
