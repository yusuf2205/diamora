import 'package:url_launcher/url_launcher.dart';

/// «Маршрут»: the route from WHERE THE PHONE IS NOW to the point, built at once, no extra taps.
/// Yandex Navigator (turn-by-turn, starts from the current position) -> Yandex Maps app (route from «my location») ->
/// the Yandex Maps web page as the last resort.
Future<void> openRoute(double lat, double lng) async {
  final candidates = [
    Uri.parse('yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lng'),
    Uri.parse('yandexmaps://maps.yandex.ru/?rtext=~$lat,$lng&rtt=auto'),
  ];
  for (final uri in candidates) {
    try {
      if (await canLaunchUrl(uri) && await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {/* try the next one */}
  }
  await launchUrl(Uri.parse('https://yandex.uz/maps/?rtext=~$lat,$lng&rtt=auto'), mode: LaunchMode.externalApplication);
}
