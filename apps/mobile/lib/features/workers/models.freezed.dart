// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FileRef {

 String get id; String get url; String get thumbUrl;
/// Create a copy of FileRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileRefCopyWith<FileRef> get copyWith => _$FileRefCopyWithImpl<FileRef>(this as FileRef, _$identity);

  /// Serializes this FileRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FileRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileRef&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.thumbUrl, _this.thumbUrl) || other.thumbUrl == _this.thumbUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FileRef;
  return Object.hash(runtimeType,_this.id,_this.url,_this.thumbUrl);
}

@override
String toString() {
  final _this = this as FileRef;
  return 'FileRef(id: ${_this.id}, url: ${_this.url}, thumbUrl: ${_this.thumbUrl})';
}


}

/// @nodoc
abstract mixin class $FileRefCopyWith<$Res>  {
  factory $FileRefCopyWith(FileRef value, $Res Function(FileRef) _then) = _$FileRefCopyWithImpl;
@useResult
$Res call({
 String id, String url, String thumbUrl
});




}
/// @nodoc
class _$FileRefCopyWithImpl<$Res>
    implements $FileRefCopyWith<$Res> {
  _$FileRefCopyWithImpl(this._self, this._then);

  final FileRef _self;
  final $Res Function(FileRef) _then;

/// Create a copy of FileRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = null,Object? thumbUrl = null,}) {
  return _then(FileRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,thumbUrl: null == thumbUrl ? _self.thumbUrl : thumbUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FileRef].
extension FileRefPatterns on FileRef {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileRef() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileRef value)  $default,){
final _that = this;
switch (_that) {
case _FileRef():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileRef value)?  $default,){
final _that = this;
switch (_that) {
case _FileRef() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String url,  String thumbUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileRef() when $default != null:
return $default(_that.id,_that.url,_that.thumbUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String url,  String thumbUrl)  $default,) {final _that = this;
switch (_that) {
case _FileRef():
return $default(_that.id,_that.url,_that.thumbUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String url,  String thumbUrl)?  $default,) {final _that = this;
switch (_that) {
case _FileRef() when $default != null:
return $default(_that.id,_that.url,_that.thumbUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FileRef implements FileRef {
  const _FileRef({required this.id, required this.url, required this.thumbUrl});
  factory _FileRef.fromJson(Map<String, dynamic> json) => _$FileRefFromJson(json);

@override final  String id;
@override final  String url;
@override final  String thumbUrl;

/// Create a copy of FileRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileRefCopyWith<_FileRef> get copyWith => __$FileRefCopyWithImpl<_FileRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FileRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileRef&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.thumbUrl, thumbUrl) || other.thumbUrl == thumbUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,url,thumbUrl);
}

@override
String toString() {
    return 'FileRef(id: $id, url: $url, thumbUrl: $thumbUrl)';
}


}

/// @nodoc
abstract mixin class _$FileRefCopyWith<$Res> implements $FileRefCopyWith<$Res> {
  factory _$FileRefCopyWith(_FileRef value, $Res Function(_FileRef) _then) = __$FileRefCopyWithImpl;
@override @useResult
$Res call({
 String id, String url, String thumbUrl
});




}
/// @nodoc
class __$FileRefCopyWithImpl<$Res>
    implements _$FileRefCopyWith<$Res> {
  __$FileRefCopyWithImpl(this._self, this._then);

  final _FileRef _self;
  final $Res Function(_FileRef) _then;

/// Create a copy of FileRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = null,Object? thumbUrl = null,}) {
  return _then(_FileRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,thumbUrl: null == thumbUrl ? _self.thumbUrl : thumbUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CollateralPhoto {

 String get id; FileRef? get file;
/// Create a copy of CollateralPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollateralPhotoCopyWith<CollateralPhoto> get copyWith => _$CollateralPhotoCopyWithImpl<CollateralPhoto>(this as CollateralPhoto, _$identity);

  /// Serializes this CollateralPhoto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CollateralPhoto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollateralPhoto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.file, _this.file) || other.file == _this.file));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CollateralPhoto;
  return Object.hash(runtimeType,_this.id,_this.file);
}

@override
String toString() {
  final _this = this as CollateralPhoto;
  return 'CollateralPhoto(id: ${_this.id}, file: ${_this.file})';
}


}

/// @nodoc
abstract mixin class $CollateralPhotoCopyWith<$Res>  {
  factory $CollateralPhotoCopyWith(CollateralPhoto value, $Res Function(CollateralPhoto) _then) = _$CollateralPhotoCopyWithImpl;
@useResult
$Res call({
 String id, FileRef? file
});


$FileRefCopyWith<$Res>? get file;

}
/// @nodoc
class _$CollateralPhotoCopyWithImpl<$Res>
    implements $CollateralPhotoCopyWith<$Res> {
  _$CollateralPhotoCopyWithImpl(this._self, this._then);

  final CollateralPhoto _self;
  final $Res Function(CollateralPhoto) _then;

/// Create a copy of CollateralPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? file = freezed,}) {
  return _then(CollateralPhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as FileRef?,
  ));
}
/// Create a copy of CollateralPhoto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FileRefCopyWith<$Res>? get file {
    if (_self.file == null) {
    return null;
  }

  return $FileRefCopyWith<$Res>(_self.file!, (value) {
    return _then(_self.copyWith(file: value));
  });
}
}


/// Adds pattern-matching-related methods to [CollateralPhoto].
extension CollateralPhotoPatterns on CollateralPhoto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollateralPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollateralPhoto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollateralPhoto value)  $default,){
final _that = this;
switch (_that) {
case _CollateralPhoto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollateralPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _CollateralPhoto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  FileRef? file)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollateralPhoto() when $default != null:
return $default(_that.id,_that.file);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  FileRef? file)  $default,) {final _that = this;
switch (_that) {
case _CollateralPhoto():
return $default(_that.id,_that.file);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  FileRef? file)?  $default,) {final _that = this;
switch (_that) {
case _CollateralPhoto() when $default != null:
return $default(_that.id,_that.file);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CollateralPhoto implements CollateralPhoto {
  const _CollateralPhoto({required this.id, this.file});
  factory _CollateralPhoto.fromJson(Map<String, dynamic> json) => _$CollateralPhotoFromJson(json);

@override final  String id;
@override final  FileRef? file;

/// Create a copy of CollateralPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollateralPhotoCopyWith<_CollateralPhoto> get copyWith => __$CollateralPhotoCopyWithImpl<_CollateralPhoto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CollateralPhotoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollateralPhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.file, file) || other.file == file));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,file);
}

@override
String toString() {
    return 'CollateralPhoto(id: $id, file: $file)';
}


}

/// @nodoc
abstract mixin class _$CollateralPhotoCopyWith<$Res> implements $CollateralPhotoCopyWith<$Res> {
  factory _$CollateralPhotoCopyWith(_CollateralPhoto value, $Res Function(_CollateralPhoto) _then) = __$CollateralPhotoCopyWithImpl;
@override @useResult
$Res call({
 String id, FileRef? file
});


@override $FileRefCopyWith<$Res>? get file;

}
/// @nodoc
class __$CollateralPhotoCopyWithImpl<$Res>
    implements _$CollateralPhotoCopyWith<$Res> {
  __$CollateralPhotoCopyWithImpl(this._self, this._then);

  final _CollateralPhoto _self;
  final $Res Function(_CollateralPhoto) _then;

/// Create a copy of CollateralPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? file = freezed,}) {
  return _then(_CollateralPhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as FileRef?,
  ));
}

/// Create a copy of CollateralPhoto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FileRefCopyWith<$Res>? get file {
    if (_self.file == null) {
    return null;
  }

  return $FileRefCopyWith<$Res>(_self.file!, (value) {
    return _then(_self.copyWith(file: value));
  });
}
}


/// @nodoc
mixin _$Collateral {

 String get id; String? get code; String get type; String get status; String? get amount; String? get description; String? get estimatedValue; String? get storageLocation; String? get declaredAt; String? get receivedAt; List<CollateralPhoto> get photos;
/// Create a copy of Collateral
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollateralCopyWith<Collateral> get copyWith => _$CollateralCopyWithImpl<Collateral>(this as Collateral, _$identity);

  /// Serializes this Collateral to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Collateral;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Collateral&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.estimatedValue, _this.estimatedValue) || other.estimatedValue == _this.estimatedValue)&&(identical(other.storageLocation, _this.storageLocation) || other.storageLocation == _this.storageLocation)&&(identical(other.declaredAt, _this.declaredAt) || other.declaredAt == _this.declaredAt)&&(identical(other.receivedAt, _this.receivedAt) || other.receivedAt == _this.receivedAt)&&const DeepCollectionEquality().equals(other.photos, _this.photos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Collateral;
  return Object.hash(runtimeType,_this.id,_this.code,_this.type,_this.status,_this.amount,_this.description,_this.estimatedValue,_this.storageLocation,_this.declaredAt,_this.receivedAt,const DeepCollectionEquality().hash(_this.photos));
}

@override
String toString() {
  final _this = this as Collateral;
  return 'Collateral(id: ${_this.id}, code: ${_this.code}, type: ${_this.type}, status: ${_this.status}, amount: ${_this.amount}, description: ${_this.description}, estimatedValue: ${_this.estimatedValue}, storageLocation: ${_this.storageLocation}, declaredAt: ${_this.declaredAt}, receivedAt: ${_this.receivedAt}, photos: ${_this.photos})';
}


}

/// @nodoc
abstract mixin class $CollateralCopyWith<$Res>  {
  factory $CollateralCopyWith(Collateral value, $Res Function(Collateral) _then) = _$CollateralCopyWithImpl;
@useResult
$Res call({
 String id, String? code, String type, String status, String? amount, String? description, String? estimatedValue, String? storageLocation, String? declaredAt, String? receivedAt, List<CollateralPhoto> photos
});




}
/// @nodoc
class _$CollateralCopyWithImpl<$Res>
    implements $CollateralCopyWith<$Res> {
  _$CollateralCopyWithImpl(this._self, this._then);

  final Collateral _self;
  final $Res Function(Collateral) _then;

/// Create a copy of Collateral
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = freezed,Object? type = null,Object? status = null,Object? amount = freezed,Object? description = freezed,Object? estimatedValue = freezed,Object? storageLocation = freezed,Object? declaredAt = freezed,Object? receivedAt = freezed,Object? photos = null,}) {
  return _then(Collateral(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,estimatedValue: freezed == estimatedValue ? _self.estimatedValue : estimatedValue // ignore: cast_nullable_to_non_nullable
as String?,storageLocation: freezed == storageLocation ? _self.storageLocation : storageLocation // ignore: cast_nullable_to_non_nullable
as String?,declaredAt: freezed == declaredAt ? _self.declaredAt : declaredAt // ignore: cast_nullable_to_non_nullable
as String?,receivedAt: freezed == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as String?,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<CollateralPhoto>,
  ));
}

}


/// Adds pattern-matching-related methods to [Collateral].
extension CollateralPatterns on Collateral {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Collateral value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Collateral() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Collateral value)  $default,){
final _that = this;
switch (_that) {
case _Collateral():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Collateral value)?  $default,){
final _that = this;
switch (_that) {
case _Collateral() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? code,  String type,  String status,  String? amount,  String? description,  String? estimatedValue,  String? storageLocation,  String? declaredAt,  String? receivedAt,  List<CollateralPhoto> photos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Collateral() when $default != null:
return $default(_that.id,_that.code,_that.type,_that.status,_that.amount,_that.description,_that.estimatedValue,_that.storageLocation,_that.declaredAt,_that.receivedAt,_that.photos);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? code,  String type,  String status,  String? amount,  String? description,  String? estimatedValue,  String? storageLocation,  String? declaredAt,  String? receivedAt,  List<CollateralPhoto> photos)  $default,) {final _that = this;
switch (_that) {
case _Collateral():
return $default(_that.id,_that.code,_that.type,_that.status,_that.amount,_that.description,_that.estimatedValue,_that.storageLocation,_that.declaredAt,_that.receivedAt,_that.photos);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? code,  String type,  String status,  String? amount,  String? description,  String? estimatedValue,  String? storageLocation,  String? declaredAt,  String? receivedAt,  List<CollateralPhoto> photos)?  $default,) {final _that = this;
switch (_that) {
case _Collateral() when $default != null:
return $default(_that.id,_that.code,_that.type,_that.status,_that.amount,_that.description,_that.estimatedValue,_that.storageLocation,_that.declaredAt,_that.receivedAt,_that.photos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Collateral extends Collateral {
  const _Collateral({required this.id, this.code, required this.type, required this.status, this.amount, this.description, this.estimatedValue, this.storageLocation, this.declaredAt, this.receivedAt,  List<CollateralPhoto> photos = const <CollateralPhoto>[]}): _photos = photos,super._();
  factory _Collateral.fromJson(Map<String, dynamic> json) => _$CollateralFromJson(json);

@override final  String id;
@override final  String? code;
@override final  String type;
@override final  String status;
@override final  String? amount;
@override final  String? description;
@override final  String? estimatedValue;
@override final  String? storageLocation;
@override final  String? declaredAt;
@override final  String? receivedAt;
 final  List<CollateralPhoto> _photos;
@override@JsonKey() List<CollateralPhoto> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}


/// Create a copy of Collateral
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollateralCopyWith<_Collateral> get copyWith => __$CollateralCopyWithImpl<_Collateral>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CollateralToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Collateral&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.description, description) || other.description == description)&&(identical(other.estimatedValue, estimatedValue) || other.estimatedValue == estimatedValue)&&(identical(other.storageLocation, storageLocation) || other.storageLocation == storageLocation)&&(identical(other.declaredAt, declaredAt) || other.declaredAt == declaredAt)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&const DeepCollectionEquality().equals(other.photos, _photos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,code,type,status,amount,description,estimatedValue,storageLocation,declaredAt,receivedAt,const DeepCollectionEquality().hash(_photos));
}

@override
String toString() {
    return 'Collateral(id: $id, code: $code, type: $type, status: $status, amount: $amount, description: $description, estimatedValue: $estimatedValue, storageLocation: $storageLocation, declaredAt: $declaredAt, receivedAt: $receivedAt, photos: $photos)';
}


}

/// @nodoc
abstract mixin class _$CollateralCopyWith<$Res> implements $CollateralCopyWith<$Res> {
  factory _$CollateralCopyWith(_Collateral value, $Res Function(_Collateral) _then) = __$CollateralCopyWithImpl;
@override @useResult
$Res call({
 String id, String? code, String type, String status, String? amount, String? description, String? estimatedValue, String? storageLocation, String? declaredAt, String? receivedAt, List<CollateralPhoto> photos
});




}
/// @nodoc
class __$CollateralCopyWithImpl<$Res>
    implements _$CollateralCopyWith<$Res> {
  __$CollateralCopyWithImpl(this._self, this._then);

  final _Collateral _self;
  final $Res Function(_Collateral) _then;

/// Create a copy of Collateral
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = freezed,Object? type = null,Object? status = null,Object? amount = freezed,Object? description = freezed,Object? estimatedValue = freezed,Object? storageLocation = freezed,Object? declaredAt = freezed,Object? receivedAt = freezed,Object? photos = null,}) {
  return _then(_Collateral(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,estimatedValue: freezed == estimatedValue ? _self.estimatedValue : estimatedValue // ignore: cast_nullable_to_non_nullable
as String?,storageLocation: freezed == storageLocation ? _self.storageLocation : storageLocation // ignore: cast_nullable_to_non_nullable
as String?,declaredAt: freezed == declaredAt ? _self.declaredAt : declaredAt // ignore: cast_nullable_to_non_nullable
as String?,receivedAt: freezed == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as String?,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<CollateralPhoto>,
  ));
}


}


/// @nodoc
mixin _$Worker {

 String get id; String get code; String get fullName; String get phone; String? get secondaryPhone; String get status; double? get latitude; double? get longitude; String? get locationReceivedAt; String get balance;@JsonKey(readValue: _managerName) String? get managerName; String? get createdAt; String? get updatedAt; Collateral? get collateral; List<Collateral> get collaterals; String? get notes; String? get rejectedReason; String? get qrCode;
/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkerCopyWith<Worker> get copyWith => _$WorkerCopyWithImpl<Worker>(this as Worker, _$identity);

  /// Serializes this Worker to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Worker;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Worker&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.fullName, _this.fullName) || other.fullName == _this.fullName)&&(identical(other.phone, _this.phone) || other.phone == _this.phone)&&(identical(other.secondaryPhone, _this.secondaryPhone) || other.secondaryPhone == _this.secondaryPhone)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.latitude, _this.latitude) || other.latitude == _this.latitude)&&(identical(other.longitude, _this.longitude) || other.longitude == _this.longitude)&&(identical(other.locationReceivedAt, _this.locationReceivedAt) || other.locationReceivedAt == _this.locationReceivedAt)&&(identical(other.balance, _this.balance) || other.balance == _this.balance)&&(identical(other.managerName, _this.managerName) || other.managerName == _this.managerName)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.collateral, _this.collateral) || other.collateral == _this.collateral)&&const DeepCollectionEquality().equals(other.collaterals, _this.collaterals)&&(identical(other.notes, _this.notes) || other.notes == _this.notes)&&(identical(other.rejectedReason, _this.rejectedReason) || other.rejectedReason == _this.rejectedReason)&&(identical(other.qrCode, _this.qrCode) || other.qrCode == _this.qrCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Worker;
  return Object.hash(runtimeType,_this.id,_this.code,_this.fullName,_this.phone,_this.secondaryPhone,_this.status,_this.latitude,_this.longitude,_this.locationReceivedAt,_this.balance,_this.managerName,_this.createdAt,_this.updatedAt,_this.collateral,const DeepCollectionEquality().hash(_this.collaterals),_this.notes,_this.rejectedReason,_this.qrCode);
}

@override
String toString() {
  final _this = this as Worker;
  return 'Worker(id: ${_this.id}, code: ${_this.code}, fullName: ${_this.fullName}, phone: ${_this.phone}, secondaryPhone: ${_this.secondaryPhone}, status: ${_this.status}, latitude: ${_this.latitude}, longitude: ${_this.longitude}, locationReceivedAt: ${_this.locationReceivedAt}, balance: ${_this.balance}, managerName: ${_this.managerName}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, collateral: ${_this.collateral}, collaterals: ${_this.collaterals}, notes: ${_this.notes}, rejectedReason: ${_this.rejectedReason}, qrCode: ${_this.qrCode})';
}


}

/// @nodoc
abstract mixin class $WorkerCopyWith<$Res>  {
  factory $WorkerCopyWith(Worker value, $Res Function(Worker) _then) = _$WorkerCopyWithImpl;
@useResult
$Res call({
 String id, String code, String fullName, String phone, String? secondaryPhone, String status, double? latitude, double? longitude, String? locationReceivedAt, String balance,@JsonKey(readValue: _managerName) String? managerName, String? createdAt, String? updatedAt, Collateral? collateral, List<Collateral> collaterals, String? notes, String? rejectedReason, String? qrCode
});


$CollateralCopyWith<$Res>? get collateral;

}
/// @nodoc
class _$WorkerCopyWithImpl<$Res>
    implements $WorkerCopyWith<$Res> {
  _$WorkerCopyWithImpl(this._self, this._then);

  final Worker _self;
  final $Res Function(Worker) _then;

/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? fullName = null,Object? phone = null,Object? secondaryPhone = freezed,Object? status = null,Object? latitude = freezed,Object? longitude = freezed,Object? locationReceivedAt = freezed,Object? balance = null,Object? managerName = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? collateral = freezed,Object? collaterals = null,Object? notes = freezed,Object? rejectedReason = freezed,Object? qrCode = freezed,}) {
  return _then(Worker(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,secondaryPhone: freezed == secondaryPhone ? _self.secondaryPhone : secondaryPhone // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,locationReceivedAt: freezed == locationReceivedAt ? _self.locationReceivedAt : locationReceivedAt // ignore: cast_nullable_to_non_nullable
as String?,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as String,managerName: freezed == managerName ? _self.managerName : managerName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,collateral: freezed == collateral ? _self.collateral : collateral // ignore: cast_nullable_to_non_nullable
as Collateral?,collaterals: null == collaterals ? _self.collaterals : collaterals // ignore: cast_nullable_to_non_nullable
as List<Collateral>,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,qrCode: freezed == qrCode ? _self.qrCode : qrCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CollateralCopyWith<$Res>? get collateral {
    if (_self.collateral == null) {
    return null;
  }

  return $CollateralCopyWith<$Res>(_self.collateral!, (value) {
    return _then(_self.copyWith(collateral: value));
  });
}
}


/// Adds pattern-matching-related methods to [Worker].
extension WorkerPatterns on Worker {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Worker value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Worker() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Worker value)  $default,){
final _that = this;
switch (_that) {
case _Worker():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Worker value)?  $default,){
final _that = this;
switch (_that) {
case _Worker() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code,  String fullName,  String phone,  String? secondaryPhone,  String status,  double? latitude,  double? longitude,  String? locationReceivedAt,  String balance, @JsonKey(readValue: _managerName)  String? managerName,  String? createdAt,  String? updatedAt,  Collateral? collateral,  List<Collateral> collaterals,  String? notes,  String? rejectedReason,  String? qrCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Worker() when $default != null:
return $default(_that.id,_that.code,_that.fullName,_that.phone,_that.secondaryPhone,_that.status,_that.latitude,_that.longitude,_that.locationReceivedAt,_that.balance,_that.managerName,_that.createdAt,_that.updatedAt,_that.collateral,_that.collaterals,_that.notes,_that.rejectedReason,_that.qrCode);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code,  String fullName,  String phone,  String? secondaryPhone,  String status,  double? latitude,  double? longitude,  String? locationReceivedAt,  String balance, @JsonKey(readValue: _managerName)  String? managerName,  String? createdAt,  String? updatedAt,  Collateral? collateral,  List<Collateral> collaterals,  String? notes,  String? rejectedReason,  String? qrCode)  $default,) {final _that = this;
switch (_that) {
case _Worker():
return $default(_that.id,_that.code,_that.fullName,_that.phone,_that.secondaryPhone,_that.status,_that.latitude,_that.longitude,_that.locationReceivedAt,_that.balance,_that.managerName,_that.createdAt,_that.updatedAt,_that.collateral,_that.collaterals,_that.notes,_that.rejectedReason,_that.qrCode);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code,  String fullName,  String phone,  String? secondaryPhone,  String status,  double? latitude,  double? longitude,  String? locationReceivedAt,  String balance, @JsonKey(readValue: _managerName)  String? managerName,  String? createdAt,  String? updatedAt,  Collateral? collateral,  List<Collateral> collaterals,  String? notes,  String? rejectedReason,  String? qrCode)?  $default,) {final _that = this;
switch (_that) {
case _Worker() when $default != null:
return $default(_that.id,_that.code,_that.fullName,_that.phone,_that.secondaryPhone,_that.status,_that.latitude,_that.longitude,_that.locationReceivedAt,_that.balance,_that.managerName,_that.createdAt,_that.updatedAt,_that.collateral,_that.collaterals,_that.notes,_that.rejectedReason,_that.qrCode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Worker extends Worker {
  const _Worker({required this.id, required this.code, required this.fullName, required this.phone, this.secondaryPhone, required this.status, this.latitude, this.longitude, this.locationReceivedAt, this.balance = '0', @JsonKey(readValue: _managerName) this.managerName, this.createdAt, this.updatedAt, this.collateral,  List<Collateral> collaterals = const <Collateral>[], this.notes, this.rejectedReason, this.qrCode}): _collaterals = collaterals,super._();
  factory _Worker.fromJson(Map<String, dynamic> json) => _$WorkerFromJson(json);

@override final  String id;
@override final  String code;
@override final  String fullName;
@override final  String phone;
@override final  String? secondaryPhone;
@override final  String status;
@override final  double? latitude;
@override final  double? longitude;
@override final  String? locationReceivedAt;
@override@JsonKey() final  String balance;
@override@JsonKey(readValue: _managerName) final  String? managerName;
@override final  String? createdAt;
@override final  String? updatedAt;
@override final  Collateral? collateral;
 final  List<Collateral> _collaterals;
@override@JsonKey() List<Collateral> get collaterals {
  if (_collaterals is EqualUnmodifiableListView) return _collaterals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_collaterals);
}

@override final  String? notes;
@override final  String? rejectedReason;
@override final  String? qrCode;

/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkerCopyWith<_Worker> get copyWith => __$WorkerCopyWithImpl<_Worker>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Worker&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.secondaryPhone, secondaryPhone) || other.secondaryPhone == secondaryPhone)&&(identical(other.status, status) || other.status == status)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.locationReceivedAt, locationReceivedAt) || other.locationReceivedAt == locationReceivedAt)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.managerName, managerName) || other.managerName == managerName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.collateral, collateral) || other.collateral == collateral)&&const DeepCollectionEquality().equals(other.collaterals, _collaterals)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.qrCode, qrCode) || other.qrCode == qrCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,code,fullName,phone,secondaryPhone,status,latitude,longitude,locationReceivedAt,balance,managerName,createdAt,updatedAt,collateral,const DeepCollectionEquality().hash(_collaterals),notes,rejectedReason,qrCode);
}

@override
String toString() {
    return 'Worker(id: $id, code: $code, fullName: $fullName, phone: $phone, secondaryPhone: $secondaryPhone, status: $status, latitude: $latitude, longitude: $longitude, locationReceivedAt: $locationReceivedAt, balance: $balance, managerName: $managerName, createdAt: $createdAt, updatedAt: $updatedAt, collateral: $collateral, collaterals: $collaterals, notes: $notes, rejectedReason: $rejectedReason, qrCode: $qrCode)';
}


}

/// @nodoc
abstract mixin class _$WorkerCopyWith<$Res> implements $WorkerCopyWith<$Res> {
  factory _$WorkerCopyWith(_Worker value, $Res Function(_Worker) _then) = __$WorkerCopyWithImpl;
@override @useResult
$Res call({
 String id, String code, String fullName, String phone, String? secondaryPhone, String status, double? latitude, double? longitude, String? locationReceivedAt, String balance,@JsonKey(readValue: _managerName) String? managerName, String? createdAt, String? updatedAt, Collateral? collateral, List<Collateral> collaterals, String? notes, String? rejectedReason, String? qrCode
});


@override $CollateralCopyWith<$Res>? get collateral;

}
/// @nodoc
class __$WorkerCopyWithImpl<$Res>
    implements _$WorkerCopyWith<$Res> {
  __$WorkerCopyWithImpl(this._self, this._then);

  final _Worker _self;
  final $Res Function(_Worker) _then;

/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? fullName = null,Object? phone = null,Object? secondaryPhone = freezed,Object? status = null,Object? latitude = freezed,Object? longitude = freezed,Object? locationReceivedAt = freezed,Object? balance = null,Object? managerName = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? collateral = freezed,Object? collaterals = null,Object? notes = freezed,Object? rejectedReason = freezed,Object? qrCode = freezed,}) {
  return _then(_Worker(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,secondaryPhone: freezed == secondaryPhone ? _self.secondaryPhone : secondaryPhone // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,locationReceivedAt: freezed == locationReceivedAt ? _self.locationReceivedAt : locationReceivedAt // ignore: cast_nullable_to_non_nullable
as String?,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as String,managerName: freezed == managerName ? _self.managerName : managerName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,collateral: freezed == collateral ? _self.collateral : collateral // ignore: cast_nullable_to_non_nullable
as Collateral?,collaterals: null == collaterals ? _self._collaterals : collaterals // ignore: cast_nullable_to_non_nullable
as List<Collateral>,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,qrCode: freezed == qrCode ? _self.qrCode : qrCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CollateralCopyWith<$Res>? get collateral {
    if (_self.collateral == null) {
    return null;
  }

  return $CollateralCopyWith<$Res>(_self.collateral!, (value) {
    return _then(_self.copyWith(collateral: value));
  });
}
}

// dart format on
