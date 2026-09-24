import '../../core/config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';
import 'models.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);
  final ApiClient _api;
  final TokenStore _tokens;

  Future<Map<String, dynamic>> _device(String platform) async => {
        'installId': await _tokens.installId(),
        'platform': platform,
        'name': 'Diamoraa app',
        'appVersion': AppConfig.appVersion,
      };

  /// Unified login step 1 (no role selector, ever): the server looks at the phone and says which field to show
  /// next. Staff only — a mastеritsa never types a phone here at all (she uses [telegramSession] instead); if she
  /// does, the server answers TELEGRAM_ONLY and the screen points her at the Telegram button.
  Future<String> identify(String phone) async {
    final res = await _api.postJson('/auth/identify', skipAuth: true, body: {'phone': phone});
    return res['method'] as String; // 'PASSWORD' | 'TELEGRAM_ONLY'
  }

  Future<Session> adminLogin(String phone, String password, {String platform = 'ANDROID'}) async =>
      _finish(await _api.postJson('/auth/admin/login', skipAuth: true, body: {'phone': phone, 'password': password, 'device': await _device(platform)}));

  // ---- WORKER: Telegram-only login (no phone/password/OTP field ever shown to her) --------------------------------
  /// Opens a login session and returns the one-time `/start <token>` deep link to hand to url_launcher.
  Future<String> telegramSession({String platform = 'ANDROID'}) async {
    final res = await _api.postJson('/auth/telegram/session', skipAuth: true, body: {'device': await _device(platform)});
    return res['deepLink'] as String;
  }

  /// Exchanges the one-time ticket from the bot's handoff URL. Never a password, never a JWT in the URL that got us
  /// here — only this POST, from this device, can turn the ticket into a real session (and only for an ACTIVE worker).
  Future<TelegramExchangeOutcome> telegramExchange(String ticket, {String platform = 'ANDROID'}) async {
    final res = await _api.postJson('/auth/telegram/exchange', skipAuth: true, body: {'ticket': ticket, 'device': await _device(platform)});
    if (res.containsKey('accessToken')) return TelegramLoggedIn(await _finish(res));
    return TelegramNotReady(res['status'] as String, res['rejectedReason'] as String?);
  }

  Future<Session> _finish(Map<String, dynamic> res) async {
    await _tokens.save(access: res['accessToken'] as String, refresh: res['refreshToken'] as String);
    return Session.fromJson((res['user'] as Map).cast<String, dynamic>());
  }

  /// Restores the session at app start (the interceptor refreshes an expired access token). Null = not signed in.
  Future<Session?> restore() async {
    if (await _tokens.readRefresh() == null) return null;
    return Session.fromJson(await _api.getJson('/auth/me'));
  }

  Future<void> logout() async {
    try {
      await _api.postJson('/auth/logout');
    } catch (_) {/* best effort: the token is removed locally either way */}
    await _tokens.clear();
  }

  /// My own password. Other devices are signed out by the server; this one stays signed in.
  Future<void> changePassword(String current, String next) => _api.postJson('/auth/change-password', body: {'currentPassword': current, 'newPassword': next});

  Future<void> logoutAll() async {
    await _api.postJson('/auth/logout-all');
    await _tokens.clear();
  }

  Future<List<DeviceSession>> sessions() async =>
      (await _api.getList('/auth/sessions')).map((j) => DeviceSession.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<void> revokeSession(String id) => _api.delete('/auth/sessions/$id');
}
