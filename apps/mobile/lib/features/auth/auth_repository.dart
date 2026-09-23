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
  /// next. WORKER: the server has already asked the Telegram bot to send the code as a side effect of this call.
  Future<String> identify(String phone) async {
    final res = await _api.postJson('/auth/identify', skipAuth: true, body: {'phone': phone});
    return res['method'] as String; // 'PASSWORD' | 'CODE'
  }

  Future<Session> adminLogin(String phone, String password, {String platform = 'ANDROID'}) async =>
      _finish(await _api.postJson('/auth/admin/login', skipAuth: true, body: {'phone': phone, 'password': password, 'device': await _device(platform)}));

  /// The API asks the Telegram bot to send a one-time code to this worker (always answers "sent": no phone enumeration).
  Future<void> requestWorkerCode(String phone) async => _api.postJson('/auth/worker/code', skipAuth: true, body: {'phone': phone});

  Future<Session> workerLogin(String phone, String code, {String platform = 'ANDROID'}) async =>
      _finish(await _api.postJson('/auth/worker/login', skipAuth: true, body: {'phone': phone, 'code': code, 'device': await _device(platform)}));

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

  Future<void> logoutAll() async {
    await _api.postJson('/auth/logout-all');
    await _tokens.clear();
  }

  Future<List<DeviceSession>> sessions() async =>
      (await _api.getList('/auth/sessions')).map((j) => DeviceSession.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<void> revokeSession(String id) => _api.delete('/auth/sessions/$id');
}
