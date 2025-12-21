// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'branding_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BrandingConfig _$BrandingConfigFromJson(Map<String, dynamic> json) {
  return _BrandingConfig.fromJson(json);
}

/// @nodoc
mixin _$BrandingConfig {
  int get primaryColorValue =>
      throw _privateConstructorUsedError; // Store int for serialization
  String get fontFamily => throw _privateConstructorUsedError;
  String get authorName => throw _privateConstructorUsedError;
  String? get logoUrl => throw _privateConstructorUsedError;

  /// Serializes this BrandingConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BrandingConfigCopyWith<BrandingConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BrandingConfigCopyWith<$Res> {
  factory $BrandingConfigCopyWith(
          BrandingConfig value, $Res Function(BrandingConfig) then) =
      _$BrandingConfigCopyWithImpl<$Res, BrandingConfig>;
  @useResult
  $Res call(
      {int primaryColorValue,
      String fontFamily,
      String authorName,
      String? logoUrl});
}

/// @nodoc
class _$BrandingConfigCopyWithImpl<$Res, $Val extends BrandingConfig>
    implements $BrandingConfigCopyWith<$Res> {
  _$BrandingConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? primaryColorValue = null,
    Object? fontFamily = null,
    Object? authorName = null,
    Object? logoUrl = freezed,
  }) {
    return _then(_value.copyWith(
      primaryColorValue: null == primaryColorValue
          ? _value.primaryColorValue
          : primaryColorValue // ignore: cast_nullable_to_non_nullable
              as int,
      fontFamily: null == fontFamily
          ? _value.fontFamily
          : fontFamily // ignore: cast_nullable_to_non_nullable
              as String,
      authorName: null == authorName
          ? _value.authorName
          : authorName // ignore: cast_nullable_to_non_nullable
              as String,
      logoUrl: freezed == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BrandingConfigImplCopyWith<$Res>
    implements $BrandingConfigCopyWith<$Res> {
  factory _$$BrandingConfigImplCopyWith(_$BrandingConfigImpl value,
          $Res Function(_$BrandingConfigImpl) then) =
      __$$BrandingConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int primaryColorValue,
      String fontFamily,
      String authorName,
      String? logoUrl});
}

/// @nodoc
class __$$BrandingConfigImplCopyWithImpl<$Res>
    extends _$BrandingConfigCopyWithImpl<$Res, _$BrandingConfigImpl>
    implements _$$BrandingConfigImplCopyWith<$Res> {
  __$$BrandingConfigImplCopyWithImpl(
      _$BrandingConfigImpl _value, $Res Function(_$BrandingConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? primaryColorValue = null,
    Object? fontFamily = null,
    Object? authorName = null,
    Object? logoUrl = freezed,
  }) {
    return _then(_$BrandingConfigImpl(
      primaryColorValue: null == primaryColorValue
          ? _value.primaryColorValue
          : primaryColorValue // ignore: cast_nullable_to_non_nullable
              as int,
      fontFamily: null == fontFamily
          ? _value.fontFamily
          : fontFamily // ignore: cast_nullable_to_non_nullable
              as String,
      authorName: null == authorName
          ? _value.authorName
          : authorName // ignore: cast_nullable_to_non_nullable
              as String,
      logoUrl: freezed == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BrandingConfigImpl extends _BrandingConfig {
  const _$BrandingConfigImpl(
      {this.primaryColorValue = 0xFF2196F3,
      this.fontFamily = 'Roboto',
      this.authorName = '',
      this.logoUrl})
      : super._();

  factory _$BrandingConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$BrandingConfigImplFromJson(json);

  @override
  @JsonKey()
  final int primaryColorValue;
// Store int for serialization
  @override
  @JsonKey()
  final String fontFamily;
  @override
  @JsonKey()
  final String authorName;
  @override
  final String? logoUrl;

  @override
  String toString() {
    return 'BrandingConfig(primaryColorValue: $primaryColorValue, fontFamily: $fontFamily, authorName: $authorName, logoUrl: $logoUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BrandingConfigImpl &&
            (identical(other.primaryColorValue, primaryColorValue) ||
                other.primaryColorValue == primaryColorValue) &&
            (identical(other.fontFamily, fontFamily) ||
                other.fontFamily == fontFamily) &&
            (identical(other.authorName, authorName) ||
                other.authorName == authorName) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, primaryColorValue, fontFamily, authorName, logoUrl);

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BrandingConfigImplCopyWith<_$BrandingConfigImpl> get copyWith =>
      __$$BrandingConfigImplCopyWithImpl<_$BrandingConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BrandingConfigImplToJson(
      this,
    );
  }
}

abstract class _BrandingConfig extends BrandingConfig {
  const factory _BrandingConfig(
      {final int primaryColorValue,
      final String fontFamily,
      final String authorName,
      final String? logoUrl}) = _$BrandingConfigImpl;
  const _BrandingConfig._() : super._();

  factory _BrandingConfig.fromJson(Map<String, dynamic> json) =
      _$BrandingConfigImpl.fromJson;

  @override
  int get primaryColorValue; // Store int for serialization
  @override
  String get fontFamily;
  @override
  String get authorName;
  @override
  String? get logoUrl;

  /// Create a copy of BrandingConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BrandingConfigImplCopyWith<_$BrandingConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
