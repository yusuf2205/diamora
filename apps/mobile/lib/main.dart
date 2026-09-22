import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_maps_mapkit_lite/init.dart' as mapkit_init;

import 'app/app.dart';
import 'core/config.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Yandex Map (SUPER_ADMIN/ADMIN/MANAGER, M2 §14, D-026): the key is supplied at build time (--dart-define), never
  // hard-coded. Without one the map screen shows a plain "not configured" message instead of a blank/crashing native view.
  if (AppConfig.yandexMapKitKey.isNotEmpty) await mapkit_init.initMapkit(apiKey: AppConfig.yandexMapKitKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [sharedPrefsProvider.overrideWithValue(prefs)], child: const YusmusApp()));
}
