import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
abstract class FileRef with _$FileRef {
  const factory FileRef({required String id, required String url, required String thumbUrl}) = _FileRef;
  factory FileRef.fromJson(Map<String, dynamic> json) => _$FileRefFromJson(json);
}

@freezed
abstract class CollateralPhoto with _$CollateralPhoto {
  const factory CollateralPhoto({required String id, FileRef? file}) = _CollateralPhoto;
  factory CollateralPhoto.fromJson(Map<String, dynamic> json) => _$CollateralPhotoFromJson(json);
}

/// Money amounts are decimal strings ("1500000") — never floats.
@freezed
abstract class Collateral with _$Collateral {
  const Collateral._();

  const factory Collateral({
    required String id,
    String? code,
    required String type, // MONEY | ITEM
    required String status, // PENDING | HELD | RETURNED
    String? amount,
    String? description,
    String? estimatedValue,
    String? storageLocation,
    String? declaredAt,
    String? receivedAt,
    @Default(<CollateralPhoto>[]) List<CollateralPhoto> photos,
  }) = _Collateral;

  factory Collateral.fromJson(Map<String, dynamic> json) => _$CollateralFromJson(json);

  bool get isMoney => type == 'MONEY';
}

/// One class for list rows and the detail screen (detail adds `collaterals` and `notes`).
@freezed
abstract class Worker with _$Worker {
  const Worker._();

  const factory Worker({
    required String id,
    required String code,
    required String fullName,
    required String phone,
    String? secondaryPhone,
    required String status,
    double? latitude,
    double? longitude,
    String? locationReceivedAt,
    @Default('0') String balance,
    String? createdAt,
    String? updatedAt,
    Collateral? collateral, // newest collateral (list rows)
    @Default(<Collateral>[]) List<Collateral> collaterals, // detail
    String? notes,
    String? rejectedReason,
    String? qrCode, // her personal QR (M2 §13), detail only
  }) = _Worker;

  factory Worker.fromJson(Map<String, dynamic> json) => _$WorkerFromJson(json);

  bool get isPending => status == 'PENDING_APPROVAL';
  bool get hasLocation => latitude != null && longitude != null;
  String get searchText => '$fullName $code $phone'.toLowerCase();
}
