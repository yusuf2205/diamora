import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

const _uuid = Uuid();

/// Dio wrapper for the NAS API: bearer token, transparent single-flight refresh on 401, X-Request-Id, Idempotency-Key
/// for safe retries, and every failure mapped to [ApiException].
class ApiClient {
  ApiClient({required this.tokens, required this.onSessionExpired, String? baseUrl, Dio? dio}) : dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    );
    this.dio.interceptors.add(_auth());
  }

  final Dio dio;
  final TokenStore tokens;
  final void Function() onSessionExpired;
  Completer<bool>? _refreshing;
  static const _skipAuth = 'skipAuth';
  static const _retried = 'retried';

  Interceptor _auth() => InterceptorsWrapper(
        onRequest: (o, h) async {
          o.headers['X-Request-Id'] = _uuid.v4();
          if (o.extra[_skipAuth] != true) {
            final t = await tokens.readAccess();
            if (t != null) o.headers['Authorization'] = 'Bearer $t';
          }
          h.next(o);
        },
        onError: (err, h) async {
          final req = err.requestOptions;
          if (err.response?.statusCode == 401 && req.extra[_skipAuth] != true && req.extra[_retried] != true) {
            if (await _refreshOnce()) {
              req.extra[_retried] = true;
              try {
                req.headers['Authorization'] = 'Bearer ${await tokens.readAccess()}';
                return h.resolve(await dio.fetch(req));
              } on DioException catch (e) {
                return h.next(e);
              }
            }
            onSessionExpired();
          }
          h.next(err);
        },
      );

  Future<bool> _refreshOnce() {
    final running = _refreshing;
    if (running != null) return running.future;
    final c = _refreshing = Completer<bool>();
    () async {
      try {
        final refresh = await tokens.readRefresh();
        if (refresh == null) return c.complete(false);
        final res = await dio.post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refresh}, options: Options(extra: {_skipAuth: true}));
        await tokens.save(access: res.data!['accessToken'] as String, refresh: res.data!['refreshToken'] as String);
        c.complete(true);
      } catch (_) {
        c.complete(false);
      } finally {
        _refreshing = null;
      }
    }();
    return c.future;
  }

  Future<T> _run<T>(Future<Response<dynamic>> Function() call, T Function(dynamic) map) async {
    try {
      return map((await call()).data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) =>
      _run(() => dio.get<dynamic>(path, queryParameters: query), (d) => (d as Map).cast<String, dynamic>());

  Future<List<dynamic>> getList(String path) => _run(() => dio.get<dynamic>(path), (d) => (d as List).toList());

  /// Pass a stable [idempotencyKey] when the call may be retried: the server executes it at most once.
  Future<Map<String, dynamic>> postJson(String path, {Object? body, String? idempotencyKey, bool skipAuth = false}) => _run(
        () => dio.post<dynamic>(path, data: body, options: Options(headers: {'Idempotency-Key': ?idempotencyKey}, extra: {_skipAuth: skipAuth})),
        (d) => d is Map ? d.cast<String, dynamic>() : <String, dynamic>{},
      );

  Future<Map<String, dynamic>> putJson(String path, {Object? body, String? idempotencyKey}) => _run(
        () => dio.put<dynamic>(path, data: body, options: Options(headers: {'Idempotency-Key': ?idempotencyKey})),
        (d) => d is Map ? d.cast<String, dynamic>() : <String, dynamic>{},
      );

  Future<void> delete(String path) => _run(() => dio.delete<dynamic>(path), (_) {});
}
