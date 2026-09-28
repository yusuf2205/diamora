import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Uzbek, Russian, English. Russian until someone picks another one on the sign-in screen or in the profile (not the
/// phone's language: many phones here are set to English while the team works in Russian or Uzbek).
const supportedLocales = [Locale('uz'), Locale('ru'), Locale('en')];

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => Locale(ref.read(sharedPrefsProvider).getString('locale') ?? 'ru');

  Future<void> set(String code) async {
    await ref.read(sharedPrefsProvider).setString('locale', code);
    state = Locale(code);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// «O'zbek · Русский · English» — on the sign-in screen and in the profile. Each name is written in its own language,
/// so anyone finds theirs whatever language the screen is in right now.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});
  static const _names = {'uz': "O'zbek", 'ru': 'Русский', 'en': 'English'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeControllerProvider).languageCode;
    return SegmentedButton<String>(
      key: const Key('languagePicker'),
      showSelectedIcon: false,
      segments: [
        for (final l in supportedLocales)
          ButtonSegment(value: l.languageCode, label: FittedBox(fit: BoxFit.scaleDown, child: Text(_names[l.languageCode]!, maxLines: 1))),
      ],
      selected: {current},
      onSelectionChanged: (s) => ref.read(localeControllerProvider.notifier).set(s.first),
    );
  }
}
