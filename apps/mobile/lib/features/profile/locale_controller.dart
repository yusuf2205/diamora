import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Uzbek (Latin and Cyrillic - many older craftswomen read Cyrillic, owner 2026-10-11), Russian, English. Russian until
/// someone picks another one on the sign-in screen or in the profile (not the phone's language: many phones here are
/// set to English while the team works in Russian or Uzbek).
const supportedLocales = [Locale('uz'), Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'), Locale('ru'), Locale('en')];

/// 'uz', 'uz_Cyrl', 'ru', 'en' - what is stored and what the picker compares
String localeKey(Locale l) => l.scriptCode == null ? l.languageCode : '${l.languageCode}_${l.scriptCode}';
Locale localeOf(String key) {
  final parts = key.split('_');
  return parts.length == 2 ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]) : Locale(key);
}

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => localeOf(ref.read(sharedPrefsProvider).getString('locale') ?? 'ru');

  Future<void> set(String code) async {
    await ref.read(sharedPrefsProvider).setString('locale', code);
    state = localeOf(code);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// «O'zbek · Русский · English» — on the sign-in screen and in the profile. Each name is written in its own language,
/// so anyone finds theirs whatever language the screen is in right now.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});
  static const _names = {'uz': "O'zbek", 'uz_Cyrl': 'Ўзбек', 'ru': 'Русский', 'en': 'English'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = localeKey(ref.watch(localeControllerProvider));
    return SegmentedButton<String>(
      key: const Key('languagePicker'),
      showSelectedIcon: false,
      segments: [
        for (final l in supportedLocales)
          ButtonSegment(value: localeKey(l), label: FittedBox(fit: BoxFit.scaleDown, child: Text(_names[localeKey(l)]!, maxLines: 1))),
      ],
      selected: {current},
      onSelectionChanged: (s) => ref.read(localeControllerProvider.notifier).set(s.first),
    );
  }
}
