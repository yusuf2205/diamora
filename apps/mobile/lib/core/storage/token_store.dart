import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Tokens live in the Android Keystore / iOS Keychain (encrypted) — never in plain preferences. The phone never holds
/// database, MinIO or Telegram credentials.
abstract class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();

  /// Random id per installation; lets the server list/revoke this device.
  Future<String> installId();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  @override
  Future<String?> readAccess() => _s.read(key: 'access_token');
  @override
  Future<String?> readRefresh() => _s.read(key: 'refresh_token');
  @override
  Future<void> save({required String access, required String refresh}) async {
    await _s.write(key: 'access_token', value: access);
    await _s.write(key: 'refresh_token', value: refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: 'access_token');
    await _s.delete(key: 'refresh_token');
  }

  @override
  Future<String> installId() async {
    final existing = await _s.read(key: 'install_id');
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _s.write(key: 'install_id', value: id);
    return id;
  }
}

class MemoryTokenStore implements TokenStore {
  String? _a;
  String? _r;
  final String _id = const Uuid().v4();
  @override
  Future<String?> readAccess() async => _a;
  @override
  Future<String?> readRefresh() async => _r;
  @override
  Future<void> save({required String access, required String refresh}) async {
    _a = access;
    _r = refresh;
  }

  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
  }

  @override
  Future<String> installId() async => _id;
}
