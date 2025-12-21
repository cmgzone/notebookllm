// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_overview.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AudioOverview _$AudioOverviewFromJson(Map<String, dynamic> json) {
  return _AudioOverview.fromJson(json);
}

/// @nodoc
mixin _$AudioOverview {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  bool get isOffline => throw _privateConstructorUsedError;

  /// Serializes this AudioOverview to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AudioOverview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioOverviewCopyWith<AudioOverview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioOverviewCopyWith<$Res> {
  factory $AudioOverviewCopyWith(
          AudioOverview value, $Res Function(AudioOverview) then) =
      _$AudioOverviewCopyWithImpl<$Res, AudioOverview>;
  @useResult
  $Res call(
      {String id,
      String title,
      String url,
      Duration duration,
      DateTime createdAt,
      bool isOffline});
}

/// @nodoc
class _$AudioOverviewCopyWithImpl<$Res, $Val extends AudioOverview>
    implements $AudioOverviewCopyWith<$Res> {
  _$AudioOverviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioOverview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? url = null,
    Object? duration = null,
    Object? createdAt = null,
    Object? isOffline = null,
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
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isOffline: null == isOffline
          ? _value.isOffline
          : isOffline // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AudioOverviewImplCopyWith<$Res>
    implements $AudioOverviewCopyWith<$Res> {
  factory _$$AudioOverviewImplCopyWith(
          _$AudioOverviewImpl value, $Res Function(_$AudioOverviewImpl) then) =
      __$$AudioOverviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String url,
      Duration duration,
      DateTime createdAt,
      bool isOffline});
}

/// @nodoc
class __$$AudioOverviewImplCopyWithImpl<$Res>
    extends _$AudioOverviewCopyWithImpl<$Res, _$AudioOverviewImpl>
    implements _$$AudioOverviewImplCopyWith<$Res> {
  __$$AudioOverviewImplCopyWithImpl(
      _$AudioOverviewImpl _value, $Res Function(_$AudioOverviewImpl) _then)
      : super(_value, _then);

  /// Create a copy of AudioOverview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? url = null,
    Object? duration = null,
    Object? createdAt = null,
    Object? isOffline = null,
  }) {
    return _then(_$AudioOverviewImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isOffline: null == isOffline
          ? _value.isOffline
          : isOffline // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AudioOverviewImpl implements _AudioOverview {
  const _$AudioOverviewImpl(
      {required this.id,
      required this.title,
      required this.url,
      required this.duration,
      required this.createdAt,
      this.isOffline = false});

  factory _$AudioOverviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$AudioOverviewImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String url;
  @override
  final Duration duration;
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final bool isOffline;

  @override
  String toString() {
    return 'AudioOverview(id: $id, title: $title, url: $url, duration: $duration, createdAt: $createdAt, isOffline: $isOffline)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioOverviewImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isOffline, isOffline) ||
                other.isOffline == isOffline));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, url, duration, createdAt, isOffline);

  /// Create a copy of AudioOverview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioOverviewImplCopyWith<_$AudioOverviewImpl> get copyWith =>
      __$$AudioOverviewImplCopyWithImpl<_$AudioOverviewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AudioOverviewImplToJson(
      this,
    );
  }
}

abstract class _AudioOverview implements AudioOverview {
  const factory _AudioOverview(
      {required final String id,
      required final String title,
      required final String url,
      required final Duration duration,
      required final DateTime createdAt,
      final bool isOffline}) = _$AudioOverviewImpl;

  factory _AudioOverview.fromJson(Map<String, dynamic> json) =
      _$AudioOverviewImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get url;
  @override
  Duration get duration;
  @override
  DateTime get createdAt;
  @override
  bool get isOffline;

  /// Create a copy of AudioOverview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioOverviewImplCopyWith<_$AudioOverviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
