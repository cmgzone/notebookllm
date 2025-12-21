// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'infographic.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Infographic _$InfographicFromJson(Map<String, dynamic> json) {
  return _Infographic.fromJson(json);
}

/// @nodoc
mixin _$Infographic {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get sourceId => throw _privateConstructorUsedError;
  String get notebookId => throw _privateConstructorUsedError;
  String? get imageUrl =>
      throw _privateConstructorUsedError; // URL if stored remotely
  String? get imageBase64 =>
      throw _privateConstructorUsedError; // Base64 if stored locally
  String? get description => throw _privateConstructorUsedError;
  InfographicStyle get style => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Infographic to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Infographic
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InfographicCopyWith<Infographic> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InfographicCopyWith<$Res> {
  factory $InfographicCopyWith(
          Infographic value, $Res Function(Infographic) then) =
      _$InfographicCopyWithImpl<$Res, Infographic>;
  @useResult
  $Res call(
      {String id,
      String title,
      String sourceId,
      String notebookId,
      String? imageUrl,
      String? imageBase64,
      String? description,
      InfographicStyle style,
      DateTime createdAt});
}

/// @nodoc
class _$InfographicCopyWithImpl<$Res, $Val extends Infographic>
    implements $InfographicCopyWith<$Res> {
  _$InfographicCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Infographic
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? sourceId = null,
    Object? notebookId = null,
    Object? imageUrl = freezed,
    Object? imageBase64 = freezed,
    Object? description = freezed,
    Object? style = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      sourceId: null == sourceId
          ? _value.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String,
      notebookId: null == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      imageBase64: freezed == imageBase64
          ? _value.imageBase64
          : imageBase64 // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as InfographicStyle,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InfographicImplCopyWith<$Res>
    implements $InfographicCopyWith<$Res> {
  factory _$$InfographicImplCopyWith(
          _$InfographicImpl value, $Res Function(_$InfographicImpl) then) =
      __$$InfographicImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String sourceId,
      String notebookId,
      String? imageUrl,
      String? imageBase64,
      String? description,
      InfographicStyle style,
      DateTime createdAt});
}

/// @nodoc
class __$$InfographicImplCopyWithImpl<$Res>
    extends _$InfographicCopyWithImpl<$Res, _$InfographicImpl>
    implements _$$InfographicImplCopyWith<$Res> {
  __$$InfographicImplCopyWithImpl(
      _$InfographicImpl _value, $Res Function(_$InfographicImpl) _then)
      : super(_value, _then);

  /// Create a copy of Infographic
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? sourceId = null,
    Object? notebookId = null,
    Object? imageUrl = freezed,
    Object? imageBase64 = freezed,
    Object? description = freezed,
    Object? style = null,
    Object? createdAt = null,
  }) {
    return _then(_$InfographicImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      sourceId: null == sourceId
          ? _value.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String,
      notebookId: null == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      imageBase64: freezed == imageBase64
          ? _value.imageBase64
          : imageBase64 // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as InfographicStyle,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InfographicImpl extends _Infographic {
  const _$InfographicImpl(
      {required this.id,
      required this.title,
      required this.sourceId,
      required this.notebookId,
      this.imageUrl,
      this.imageBase64,
      this.description,
      this.style = InfographicStyle.modern,
      required this.createdAt})
      : super._();

  factory _$InfographicImpl.fromJson(Map<String, dynamic> json) =>
      _$$InfographicImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String sourceId;
  @override
  final String notebookId;
  @override
  final String? imageUrl;
// URL if stored remotely
  @override
  final String? imageBase64;
// Base64 if stored locally
  @override
  final String? description;
  @override
  @JsonKey()
  final InfographicStyle style;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Infographic(id: $id, title: $title, sourceId: $sourceId, notebookId: $notebookId, imageUrl: $imageUrl, imageBase64: $imageBase64, description: $description, style: $style, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InfographicImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.notebookId, notebookId) ||
                other.notebookId == notebookId) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.imageBase64, imageBase64) ||
                other.imageBase64 == imageBase64) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.style, style) || other.style == style) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, sourceId, notebookId,
      imageUrl, imageBase64, description, style, createdAt);

  /// Create a copy of Infographic
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InfographicImplCopyWith<_$InfographicImpl> get copyWith =>
      __$$InfographicImplCopyWithImpl<_$InfographicImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InfographicImplToJson(
      this,
    );
  }
}

abstract class _Infographic extends Infographic {
  const factory _Infographic(
      {required final String id,
      required final String title,
      required final String sourceId,
      required final String notebookId,
      final String? imageUrl,
      final String? imageBase64,
      final String? description,
      final InfographicStyle style,
      required final DateTime createdAt}) = _$InfographicImpl;
  const _Infographic._() : super._();

  factory _Infographic.fromJson(Map<String, dynamic> json) =
      _$InfographicImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get sourceId;
  @override
  String get notebookId;
  @override
  String? get imageUrl; // URL if stored remotely
  @override
  String? get imageBase64; // Base64 if stored locally
  @override
  String? get description;
  @override
  InfographicStyle get style;
  @override
  DateTime get createdAt;

  /// Create a copy of Infographic
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InfographicImplCopyWith<_$InfographicImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
