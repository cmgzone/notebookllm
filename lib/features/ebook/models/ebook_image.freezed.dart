// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ebook_image.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EbookImage _$EbookImageFromJson(Map<String, dynamic> json) {
  return _EbookImage.fromJson(json);
}

/// @nodoc
mixin _$EbookImage {
  String get id => throw _privateConstructorUsedError;
  String get prompt => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  String get caption => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;

  /// Serializes this EbookImage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EbookImage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EbookImageCopyWith<EbookImage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EbookImageCopyWith<$Res> {
  factory $EbookImageCopyWith(
          EbookImage value, $Res Function(EbookImage) then) =
      _$EbookImageCopyWithImpl<$Res, EbookImage>;
  @useResult
  $Res call(
      {String id, String prompt, String url, String caption, String type});
}

/// @nodoc
class _$EbookImageCopyWithImpl<$Res, $Val extends EbookImage>
    implements $EbookImageCopyWith<$Res> {
  _$EbookImageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EbookImage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? prompt = null,
    Object? url = null,
    Object? caption = null,
    Object? type = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      prompt: null == prompt
          ? _value.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      caption: null == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EbookImageImplCopyWith<$Res>
    implements $EbookImageCopyWith<$Res> {
  factory _$$EbookImageImplCopyWith(
          _$EbookImageImpl value, $Res Function(_$EbookImageImpl) then) =
      __$$EbookImageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id, String prompt, String url, String caption, String type});
}

/// @nodoc
class __$$EbookImageImplCopyWithImpl<$Res>
    extends _$EbookImageCopyWithImpl<$Res, _$EbookImageImpl>
    implements _$$EbookImageImplCopyWith<$Res> {
  __$$EbookImageImplCopyWithImpl(
      _$EbookImageImpl _value, $Res Function(_$EbookImageImpl) _then)
      : super(_value, _then);

  /// Create a copy of EbookImage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? prompt = null,
    Object? url = null,
    Object? caption = null,
    Object? type = null,
  }) {
    return _then(_$EbookImageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      prompt: null == prompt
          ? _value.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      caption: null == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EbookImageImpl extends _EbookImage {
  const _$EbookImageImpl(
      {required this.id,
      required this.prompt,
      required this.url,
      this.caption = '',
      this.type = 'generated'})
      : super._();

  factory _$EbookImageImpl.fromJson(Map<String, dynamic> json) =>
      _$$EbookImageImplFromJson(json);

  @override
  final String id;
  @override
  final String prompt;
  @override
  final String url;
  @override
  @JsonKey()
  final String caption;
  @override
  @JsonKey()
  final String type;

  @override
  String toString() {
    return 'EbookImage(id: $id, prompt: $prompt, url: $url, caption: $caption, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EbookImageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.prompt, prompt) || other.prompt == prompt) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, prompt, url, caption, type);

  /// Create a copy of EbookImage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EbookImageImplCopyWith<_$EbookImageImpl> get copyWith =>
      __$$EbookImageImplCopyWithImpl<_$EbookImageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EbookImageImplToJson(
      this,
    );
  }
}

abstract class _EbookImage extends EbookImage {
  const factory _EbookImage(
      {required final String id,
      required final String prompt,
      required final String url,
      final String caption,
      final String type}) = _$EbookImageImpl;
  const _EbookImage._() : super._();

  factory _EbookImage.fromJson(Map<String, dynamic> json) =
      _$EbookImageImpl.fromJson;

  @override
  String get id;
  @override
  String get prompt;
  @override
  String get url;
  @override
  String get caption;
  @override
  String get type;

  /// Create a copy of EbookImage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EbookImageImplCopyWith<_$EbookImageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
