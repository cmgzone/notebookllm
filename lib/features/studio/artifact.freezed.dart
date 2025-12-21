// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'artifact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Artifact _$ArtifactFromJson(Map<String, dynamic> json) {
  return _Artifact.fromJson(json);
}

/// @nodoc
mixin _$Artifact {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get type =>
      throw _privateConstructorUsedError; // study-guide, brief, faq, timeline, mind-map
  String get content => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String? get notebookId => throw _privateConstructorUsedError;

  /// Serializes this Artifact to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Artifact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ArtifactCopyWith<Artifact> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArtifactCopyWith<$Res> {
  factory $ArtifactCopyWith(Artifact value, $Res Function(Artifact) then) =
      _$ArtifactCopyWithImpl<$Res, Artifact>;
  @useResult
  $Res call(
      {String id,
      String title,
      String type,
      String content,
      DateTime createdAt,
      String? notebookId});
}

/// @nodoc
class _$ArtifactCopyWithImpl<$Res, $Val extends Artifact>
    implements $ArtifactCopyWith<$Res> {
  _$ArtifactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Artifact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? type = null,
    Object? content = null,
    Object? createdAt = null,
    Object? notebookId = freezed,
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      notebookId: freezed == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ArtifactImplCopyWith<$Res>
    implements $ArtifactCopyWith<$Res> {
  factory _$$ArtifactImplCopyWith(
          _$ArtifactImpl value, $Res Function(_$ArtifactImpl) then) =
      __$$ArtifactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String type,
      String content,
      DateTime createdAt,
      String? notebookId});
}

/// @nodoc
class __$$ArtifactImplCopyWithImpl<$Res>
    extends _$ArtifactCopyWithImpl<$Res, _$ArtifactImpl>
    implements _$$ArtifactImplCopyWith<$Res> {
  __$$ArtifactImplCopyWithImpl(
      _$ArtifactImpl _value, $Res Function(_$ArtifactImpl) _then)
      : super(_value, _then);

  /// Create a copy of Artifact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? type = null,
    Object? content = null,
    Object? createdAt = null,
    Object? notebookId = freezed,
  }) {
    return _then(_$ArtifactImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      notebookId: freezed == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ArtifactImpl implements _Artifact {
  const _$ArtifactImpl(
      {required this.id,
      required this.title,
      required this.type,
      required this.content,
      required this.createdAt,
      this.notebookId});

  factory _$ArtifactImpl.fromJson(Map<String, dynamic> json) =>
      _$$ArtifactImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String type;
// study-guide, brief, faq, timeline, mind-map
  @override
  final String content;
  @override
  final DateTime createdAt;
  @override
  final String? notebookId;

  @override
  String toString() {
    return 'Artifact(id: $id, title: $title, type: $type, content: $content, createdAt: $createdAt, notebookId: $notebookId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArtifactImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.notebookId, notebookId) ||
                other.notebookId == notebookId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, type, content, createdAt, notebookId);

  /// Create a copy of Artifact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ArtifactImplCopyWith<_$ArtifactImpl> get copyWith =>
      __$$ArtifactImplCopyWithImpl<_$ArtifactImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ArtifactImplToJson(
      this,
    );
  }
}

abstract class _Artifact implements Artifact {
  const factory _Artifact(
      {required final String id,
      required final String title,
      required final String type,
      required final String content,
      required final DateTime createdAt,
      final String? notebookId}) = _$ArtifactImpl;

  factory _Artifact.fromJson(Map<String, dynamic> json) =
      _$ArtifactImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get type; // study-guide, brief, faq, timeline, mind-map
  @override
  String get content;
  @override
  DateTime get createdAt;
  @override
  String? get notebookId;

  /// Create a copy of Artifact
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ArtifactImplCopyWith<_$ArtifactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
