import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import 'models.dart';

const _cachedSessionKey = 'cached_session';

/// The signed-in user (null = signed out). Loading = restoring a stored session at app start.
class AuthController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final prefs = ref.read(sharedPrefsProvider);
    try {
      final s = await ref.read(authRepositoryProvider).restore();
      if (s != null) {
        await prefs.setString(_cachedSessionKey, jsonEncode(s.toJson()));
        await ref.read(realtimeClientProvider).connect();
      }
      return s;
    } on ApiException catch (e) {
      // opened offline with a stored login: keep working from the local cache; the server still enforces everything
      if (e.isOffline && await ref.read(tokenStoreProvider).readRefresh() != null) {
        final cached = prefs.getString(_cachedSessionKey);
        if (cached != null) return Session.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      return null;
    }
  }

  Future<void> adminLogin(String phone, String password) => _signIn(() => ref.read(authRepositoryProvider).adminLogin(phone, password));

  /// WORKER Telegram-only login: unlike [adminLogin], this may legitimately NOT produce a session (pending
  /// approval, rejected, paused) — the caller (the App Link handler) decides what screen to show from the outcome.
  Future<TelegramExchangeOutcome> telegramExchange(String ticket) async {
    final outcome = await ref.read(authRepositoryProvider).telegramExchange(ticket);
    if (outcome is TelegramLoggedIn) {
      await ref.read(sharedPrefsProvider).setString(_cachedSessionKey, jsonEncode(outcome.session.toJson()));
      state = AsyncData(outcome.session);
      await ref.read(realtimeClientProvider).connect();
    }
    return outcome;
  }

  /// Throws [ApiException] so the login form can show a precise message.
  Future<void> _signIn(Future<Session> Function() login) async {
    final s = await login();
    await ref.read(sharedPrefsProvider).setString(_cachedSessionKey, jsonEncode(s.toJson()));
    state = AsyncData(s);
    await ref.read(realtimeClientProvider).connect();
  }

  Future<void> logout({bool everywhere = false}) async {
    final repo = ref.read(authRepositoryProvider);
    everywhere ? await repo.logoutAll() : await repo.logout();
    await _wipe();
    state = const AsyncData(null);
  }

  Future<void> sessionExpired() async {
    if (state.value == null) return;
    await ref.read(tokenStoreProvider).clear();
    await _wipe();
    state = const AsyncData(null);
  }

  Future<void> _wipe() async {
    await ref.read(realtimeClientProvider).disconnect();
    await ref.read(sharedPrefsProvider).remove(_cachedSessionKey);
    await ref.read(workerRepositoryProvider).clear(); // the next user must not see this user's data
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(AuthController.new);
