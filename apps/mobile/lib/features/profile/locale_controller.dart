import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

const supportedLocales = [Locale('ru'), Locale('uz')];

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => Locale(ref.read(sharedPrefsProvider).getString('locale') ?? 'ru');

  Future<void> set(String code) async {
    await ref.read(sharedPrefsProvider).setString('locale', code);
    state = Locale(code);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
