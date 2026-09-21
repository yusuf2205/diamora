import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

/// The signed-in user (`/auth/*` responses). The role decides which app shell is shown; the SERVER enforces it anyway.
@freezed
abstract class Session with _$Session {
  const Session._();

  const factory Session({
    required String id,
    required String fullName,
    required String phone,
    required String role,
    String? workerId,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

  bool get isAdmin => role == 'ADMIN';
  bool get isWorker => role == 'WORKER';
}

@freezed
abstract class DeviceSession with _$DeviceSession {
  const factory DeviceSession({
    required String id,
    required bool current,
    required String lastUsedAt,
    String? ip,
    required DeviceInfo device,
  }) = _DeviceSession;

  factory DeviceSession.fromJson(Map<String, dynamic> json) => _$DeviceSessionFromJson(json);
}

@freezed
abstract class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({String? name, required String platform, String? appVersion}) = _DeviceInfo;
  factory DeviceInfo.fromJson(Map<String, dynamic> json) => _$DeviceInfoFromJson(json);
}
