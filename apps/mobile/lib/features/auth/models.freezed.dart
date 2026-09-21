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
mixin _$Session {

 String get id; String get fullName; String get phone; String get role; String? get workerId;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Session;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.fullName, _this.fullName) || other.fullName == _this.fullName)&&(identical(other.phone, _this.phone) || other.phone == _this.phone)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.workerId, _this.workerId) || other.workerId == _this.workerId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Session;
  return Object.hash(runtimeType,_this.id,_this.fullName,_this.phone,_this.role,_this.workerId);
}

@override
String toString() {
  final _this = this as Session;
  return 'Session(id: ${_this.id}, fullName: ${_this.fullName}, phone: ${_this.phone}, role: ${_this.role}, workerId: ${_this.workerId})';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
 String id, String fullName, String phone, String role, String? workerId
});




}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fullName = null,Object? phone = null,Object? role = null,Object? workerId = freezed,}) {
  return _then(Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,workerId: freezed == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fullName,  String phone,  String role,  String? workerId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.fullName,_that.phone,_that.role,_that.workerId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fullName,  String phone,  String role,  String? workerId)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.id,_that.fullName,_that.phone,_that.role,_that.workerId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fullName,  String phone,  String role,  String? workerId)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.fullName,_that.phone,_that.role,_that.workerId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Session extends Session {
  const _Session({required this.id, required this.fullName, required this.phone, required this.role, this.workerId}): super._();
  factory _Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

@override final  String id;
@override final  String fullName;
@override final  String phone;
@override final  String role;
@override final  String? workerId;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.role, role) || other.role == role)&&(identical(other.workerId, workerId) || other.workerId == workerId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,fullName,phone,role,workerId);
}

@override
String toString() {
    return 'Session(id: $id, fullName: $fullName, phone: $phone, role: $role, workerId: $workerId)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String fullName, String phone, String role, String? workerId
});




}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fullName = null,Object? phone = null,Object? role = null,Object? workerId = freezed,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,workerId: freezed == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DeviceSession {

 String get id; bool get current; String get lastUsedAt; String? get ip; DeviceInfo get device;
/// Create a copy of DeviceSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceSessionCopyWith<DeviceSession> get copyWith => _$DeviceSessionCopyWithImpl<DeviceSession>(this as DeviceSession, _$identity);

  /// Serializes this DeviceSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceSession&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.current, _this.current) || other.current == _this.current)&&(identical(other.lastUsedAt, _this.lastUsedAt) || other.lastUsedAt == _this.lastUsedAt)&&(identical(other.ip, _this.ip) || other.ip == _this.ip)&&(identical(other.device, _this.device) || other.device == _this.device));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceSession;
  return Object.hash(runtimeType,_this.id,_this.current,_this.lastUsedAt,_this.ip,_this.device);
}

@override
String toString() {
  final _this = this as DeviceSession;
  return 'DeviceSession(id: ${_this.id}, current: ${_this.current}, lastUsedAt: ${_this.lastUsedAt}, ip: ${_this.ip}, device: ${_this.device})';
}


}

/// @nodoc
abstract mixin class $DeviceSessionCopyWith<$Res>  {
  factory $DeviceSessionCopyWith(DeviceSession value, $Res Function(DeviceSession) _then) = _$DeviceSessionCopyWithImpl;
@useResult
$Res call({
 String id, bool current, String lastUsedAt, String? ip, DeviceInfo device
});


$DeviceInfoCopyWith<$Res> get device;

}
/// @nodoc
class _$DeviceSessionCopyWithImpl<$Res>
    implements $DeviceSessionCopyWith<$Res> {
  _$DeviceSessionCopyWithImpl(this._self, this._then);

  final DeviceSession _self;
  final $Res Function(DeviceSession) _then;

/// Create a copy of DeviceSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? current = null,Object? lastUsedAt = null,Object? ip = freezed,Object? device = null,}) {
  return _then(DeviceSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,lastUsedAt: null == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as String,ip: freezed == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String?,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as DeviceInfo,
  ));
}
/// Create a copy of DeviceSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceInfoCopyWith<$Res> get device {
  
  return $DeviceInfoCopyWith<$Res>(_self.device, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}


/// Adds pattern-matching-related methods to [DeviceSession].
extension DeviceSessionPatterns on DeviceSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceSession value)  $default,){
final _that = this;
switch (_that) {
case _DeviceSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceSession value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  bool current,  String lastUsedAt,  String? ip,  DeviceInfo device)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceSession() when $default != null:
return $default(_that.id,_that.current,_that.lastUsedAt,_that.ip,_that.device);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  bool current,  String lastUsedAt,  String? ip,  DeviceInfo device)  $default,) {final _that = this;
switch (_that) {
case _DeviceSession():
return $default(_that.id,_that.current,_that.lastUsedAt,_that.ip,_that.device);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  bool current,  String lastUsedAt,  String? ip,  DeviceInfo device)?  $default,) {final _that = this;
switch (_that) {
case _DeviceSession() when $default != null:
return $default(_that.id,_that.current,_that.lastUsedAt,_that.ip,_that.device);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceSession implements DeviceSession {
  const _DeviceSession({required this.id, required this.current, required this.lastUsedAt, this.ip, required this.device});
  factory _DeviceSession.fromJson(Map<String, dynamic> json) => _$DeviceSessionFromJson(json);

@override final  String id;
@override final  bool current;
@override final  String lastUsedAt;
@override final  String? ip;
@override final  DeviceInfo device;

/// Create a copy of DeviceSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceSessionCopyWith<_DeviceSession> get copyWith => __$DeviceSessionCopyWithImpl<_DeviceSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceSession&&(identical(other.id, id) || other.id == id)&&(identical(other.current, current) || other.current == current)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.device, device) || other.device == device));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,current,lastUsedAt,ip,device);
}

@override
String toString() {
    return 'DeviceSession(id: $id, current: $current, lastUsedAt: $lastUsedAt, ip: $ip, device: $device)';
}


}

/// @nodoc
abstract mixin class _$DeviceSessionCopyWith<$Res> implements $DeviceSessionCopyWith<$Res> {
  factory _$DeviceSessionCopyWith(_DeviceSession value, $Res Function(_DeviceSession) _then) = __$DeviceSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, bool current, String lastUsedAt, String? ip, DeviceInfo device
});


@override $DeviceInfoCopyWith<$Res> get device;

}
/// @nodoc
class __$DeviceSessionCopyWithImpl<$Res>
    implements _$DeviceSessionCopyWith<$Res> {
  __$DeviceSessionCopyWithImpl(this._self, this._then);

  final _DeviceSession _self;
  final $Res Function(_DeviceSession) _then;

/// Create a copy of DeviceSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? current = null,Object? lastUsedAt = null,Object? ip = freezed,Object? device = null,}) {
  return _then(_DeviceSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,lastUsedAt: null == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as String,ip: freezed == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String?,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as DeviceInfo,
  ));
}

/// Create a copy of DeviceSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceInfoCopyWith<$Res> get device {
  
  return $DeviceInfoCopyWith<$Res>(_self.device, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}


/// @nodoc
mixin _$DeviceInfo {

 String? get name; String get platform; String? get appVersion;
/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceInfoCopyWith<DeviceInfo> get copyWith => _$DeviceInfoCopyWithImpl<DeviceInfo>(this as DeviceInfo, _$identity);

  /// Serializes this DeviceInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceInfo&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceInfo;
  return Object.hash(runtimeType,_this.name,_this.platform,_this.appVersion);
}

@override
String toString() {
  final _this = this as DeviceInfo;
  return 'DeviceInfo(name: ${_this.name}, platform: ${_this.platform}, appVersion: ${_this.appVersion})';
}


}

/// @nodoc
abstract mixin class $DeviceInfoCopyWith<$Res>  {
  factory $DeviceInfoCopyWith(DeviceInfo value, $Res Function(DeviceInfo) _then) = _$DeviceInfoCopyWithImpl;
@useResult
$Res call({
 String? name, String platform, String? appVersion
});




}
/// @nodoc
class _$DeviceInfoCopyWithImpl<$Res>
    implements $DeviceInfoCopyWith<$Res> {
  _$DeviceInfoCopyWithImpl(this._self, this._then);

  final DeviceInfo _self;
  final $Res Function(DeviceInfo) _then;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? platform = null,Object? appVersion = freezed,}) {
  return _then(DeviceInfo(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceInfo].
extension DeviceInfoPatterns on DeviceInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceInfo value)  $default,){
final _that = this;
switch (_that) {
case _DeviceInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceInfo value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name,  String platform,  String? appVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceInfo() when $default != null:
return $default(_that.name,_that.platform,_that.appVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name,  String platform,  String? appVersion)  $default,) {final _that = this;
switch (_that) {
case _DeviceInfo():
return $default(_that.name,_that.platform,_that.appVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name,  String platform,  String? appVersion)?  $default,) {final _that = this;
switch (_that) {
case _DeviceInfo() when $default != null:
return $default(_that.name,_that.platform,_that.appVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceInfo implements DeviceInfo {
  const _DeviceInfo({this.name, required this.platform, this.appVersion});
  factory _DeviceInfo.fromJson(Map<String, dynamic> json) => _$DeviceInfoFromJson(json);

@override final  String? name;
@override final  String platform;
@override final  String? appVersion;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceInfoCopyWith<_DeviceInfo> get copyWith => __$DeviceInfoCopyWithImpl<_DeviceInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,platform,appVersion);
}

@override
String toString() {
    return 'DeviceInfo(name: $name, platform: $platform, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class _$DeviceInfoCopyWith<$Res> implements $DeviceInfoCopyWith<$Res> {
  factory _$DeviceInfoCopyWith(_DeviceInfo value, $Res Function(_DeviceInfo) _then) = __$DeviceInfoCopyWithImpl;
@override @useResult
$Res call({
 String? name, String platform, String? appVersion
});




}
/// @nodoc
class __$DeviceInfoCopyWithImpl<$Res>
    implements _$DeviceInfoCopyWith<$Res> {
  __$DeviceInfoCopyWithImpl(this._self, this._then);

  final _DeviceInfo _self;
  final $Res Function(_DeviceInfo) _then;

/// Create a copy of DeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? platform = null,Object? appVersion = freezed,}) {
  return _then(_DeviceInfo(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
