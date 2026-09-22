// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FileRef _$FileRefFromJson(Map<String, dynamic> json) => _FileRef(
  id: json['id'] as String,
  url: json['url'] as String,
  thumbUrl: json['thumbUrl'] as String,
);

Map<String, dynamic> _$FileRefToJson(_FileRef instance) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'thumbUrl': instance.thumbUrl,
};

_CollateralPhoto _$CollateralPhotoFromJson(Map<String, dynamic> json) =>
    _CollateralPhoto(
      id: json['id'] as String,
      file: json['file'] == null
          ? null
          : FileRef.fromJson(json['file'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CollateralPhotoToJson(_CollateralPhoto instance) =>
    <String, dynamic>{'id': instance.id, 'file': instance.file};

_Collateral _$CollateralFromJson(Map<String, dynamic> json) => _Collateral(
  id: json['id'] as String,
  code: json['code'] as String?,
  type: json['type'] as String,
  status: json['status'] as String,
  amount: json['amount'] as String?,
  description: json['description'] as String?,
  estimatedValue: json['estimatedValue'] as String?,
  storageLocation: json['storageLocation'] as String?,
  declaredAt: json['declaredAt'] as String?,
  receivedAt: json['receivedAt'] as String?,
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => CollateralPhoto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CollateralPhoto>[],
);

Map<String, dynamic> _$CollateralToJson(_Collateral instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'type': instance.type,
      'status': instance.status,
      'amount': instance.amount,
      'description': instance.description,
      'estimatedValue': instance.estimatedValue,
      'storageLocation': instance.storageLocation,
      'declaredAt': instance.declaredAt,
      'receivedAt': instance.receivedAt,
      'photos': instance.photos,
    };

_Worker _$WorkerFromJson(Map<String, dynamic> json) => _Worker(
  id: json['id'] as String,
  code: json['code'] as String,
  fullName: json['fullName'] as String,
  phone: json['phone'] as String,
  secondaryPhone: json['secondaryPhone'] as String?,
  status: json['status'] as String,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  locationReceivedAt: json['locationReceivedAt'] as String?,
  balance: json['balance'] as String? ?? '0',
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
  collateral: json['collateral'] == null
      ? null
      : Collateral.fromJson(json['collateral'] as Map<String, dynamic>),
  collaterals:
      (json['collaterals'] as List<dynamic>?)
          ?.map((e) => Collateral.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Collateral>[],
  notes: json['notes'] as String?,
  rejectedReason: json['rejectedReason'] as String?,
  qrCode: json['qrCode'] as String?,
);

Map<String, dynamic> _$WorkerToJson(_Worker instance) => <String, dynamic>{
  'id': instance.id,
  'code': instance.code,
  'fullName': instance.fullName,
  'phone': instance.phone,
  'secondaryPhone': instance.secondaryPhone,
  'status': instance.status,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'locationReceivedAt': instance.locationReceivedAt,
  'balance': instance.balance,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'collateral': instance.collateral,
  'collaterals': instance.collaterals,
  'notes': instance.notes,
  'rejectedReason': instance.rejectedReason,
  'qrCode': instance.qrCode,
};
