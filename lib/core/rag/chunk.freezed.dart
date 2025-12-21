// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chunk.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Chunk _$ChunkFromJson(Map<String, dynamic> json) {
  return _Chunk.fromJson(json);
}

/// @nodoc
mixin _$Chunk {
  String get id => throw _privateConstructorUsedError;
  String get sourceId => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  int get start => throw _privateConstructorUsedError;
  int get end => throw _privateConstructorUsedError;
  List<double> get embedding => throw _privateConstructorUsedError;

  /// Serializes this Chunk to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Chunk
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChunkCopyWith<Chunk> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChunkCopyWith<$Res> {
  factory $ChunkCopyWith(Chunk value, $Res Function(Chunk) then) =
      _$ChunkCopyWithImpl<$Res, Chunk>;
  @useResult
  $Res call(
      {String id,
      String sourceId,
      String text,
      int start,
      int end,
      List<double> embedding});
}

/// @nodoc
class _$ChunkCopyWithImpl<$Res, $Val extends Chunk>
    implements $ChunkCopyWith<$Res> {
  _$ChunkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Chunk
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceId = null,
    Object? text = null,
    Object? start = null,
    Object? end = null,
    Object? embedding = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sourceId: null == sourceId
          ? _value.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as int,
      end: null == end
          ? _value.end
          : end // ignore: cast_nullable_to_non_nullable
              as int,
      embedding: null == embedding
          ? _value.embedding
          : embedding // ignore: cast_nullable_to_non_nullable
              as List<double>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChunkImplCopyWith<$Res> implements $ChunkCopyWith<$Res> {
  factory _$$ChunkImplCopyWith(
          _$ChunkImpl value, $Res Function(_$ChunkImpl) then) =
      __$$ChunkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String sourceId,
      String text,
      int start,
      int end,
      List<double> embedding});
}

/// @nodoc
class __$$ChunkImplCopyWithImpl<$Res>
    extends _$ChunkCopyWithImpl<$Res, _$ChunkImpl>
    implements _$$ChunkImplCopyWith<$Res> {
  __$$ChunkImplCopyWithImpl(
      _$ChunkImpl _value, $Res Function(_$ChunkImpl) _then)
      : super(_value, _then);

  /// Create a copy of Chunk
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceId = null,
    Object? text = null,
    Object? start = null,
    Object? end = null,
    Object? embedding = null,
  }) {
    return _then(_$ChunkImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sourceId: null == sourceId
          ? _value.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as int,
      end: null == end
          ? _value.end
          : end // ignore: cast_nullable_to_non_nullable
              as int,
      embedding: null == embedding
          ? _value._embedding
          : embedding // ignore: cast_nullable_to_non_nullable
              as List<double>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChunkImpl implements _Chunk {
  const _$ChunkImpl(
      {required this.id,
      required this.sourceId,
      required this.text,
      required this.start,
      required this.end,
      required final List<double> embedding})
      : _embedding = embedding;

  factory _$ChunkImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChunkImplFromJson(json);

  @override
  final String id;
  @override
  final String sourceId;
  @override
  final String text;
  @override
  final int start;
  @override
  final int end;
  final List<double> _embedding;
  @override
  List<double> get embedding {
    if (_embedding is EqualUnmodifiableListView) return _embedding;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_embedding);
  }

  @override
  String toString() {
    return 'Chunk(id: $id, sourceId: $sourceId, text: $text, start: $start, end: $end, embedding: $embedding)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChunkImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end) &&
            const DeepCollectionEquality()
                .equals(other._embedding, _embedding));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, sourceId, text, start, end,
      const DeepCollectionEquality().hash(_embedding));

  /// Create a copy of Chunk
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChunkImplCopyWith<_$ChunkImpl> get copyWith =>
      __$$ChunkImplCopyWithImpl<_$ChunkImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChunkImplToJson(
      this,
    );
  }
}

abstract class _Chunk implements Chunk {
  const factory _Chunk(
      {required final String id,
      required final String sourceId,
      required final String text,
      required final int start,
      required final int end,
      required final List<double> embedding}) = _$ChunkImpl;

  factory _Chunk.fromJson(Map<String, dynamic> json) = _$ChunkImpl.fromJson;

  @override
  String get id;
  @override
  String get sourceId;
  @override
  String get text;
  @override
  int get start;
  @override
  int get end;
  @override
  List<double> get embedding;

  /// Create a copy of Chunk
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChunkImplCopyWith<_$ChunkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
