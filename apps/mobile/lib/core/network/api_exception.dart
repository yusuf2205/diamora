import 'package:dio/dio.dart';

/// Stable error codes of the API (`error.code`, packages/shared/src/basics.ts).
class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.status, this.details, this.retryAfterSeconds});

  final String code;
  final String message;
  final int? status;
  final Object? details;
  final int? retryAfterSeconds;

  bool get isOffline => code == 'NETWORK';

  factory ApiException.network() => ApiException(code: 'NETWORK', message: 'No connection to the server');

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) return ApiException.network();
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final retry = res.headers.value('retry-after');
      return ApiException(
        code: (err['code'] as String?) ?? 'UNKNOWN',
        message: (err['message'] as String?) ?? 'Request failed',
        status: res.statusCode,
        details: err['details'],
        retryAfterSeconds: retry == null ? null : int.tryParse(retry),
      );
    }
    return ApiException(code: 'UNKNOWN', message: 'Request failed', status: res.statusCode);
  }

  @override
  String toString() => 'ApiException($code, $status): $message';
}
