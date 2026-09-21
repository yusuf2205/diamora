// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Session _$SessionFromJson(Map<String, dynamic> json) => _Session(
  id: json['id'] as String,
  fullName: json['fullName'] as String,
  phone: json['phone'] as String,
  role: json['role'] as String,
  workerId: json['workerId'] as String?,
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'id': instance.id,
  'fullName': instance.fullName,
  'phone': instance.phone,
  'role': instance.role,
  'workerId': instance.workerId,
};

_DeviceSession _$DeviceSessionFromJson(Map<String, dynamic> json) =>
    _DeviceSession(
      id: json['id'] as String,
      current: json['current'] as bool,
      lastUsedAt: json['lastUsedAt'] as String,
      ip: json['ip'] as String?,
      device: DeviceInfo.fromJson(json['device'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeviceSessionToJson(_DeviceSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'current': instance.current,
      'lastUsedAt': instance.lastUsedAt,
      'ip': instance.ip,
      'device': instance.device,
    };

_DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) => _DeviceInfo(
  name: json['name'] as String?,
  platform: json['platform'] as String,
  appVersion: json['appVersion'] as String?,
);

Map<String, dynamic> _$DeviceInfoToJson(_DeviceInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'platform': instance.platform,
      'appVersion': instance.appVersion,
    };
