// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Source _$SourceFromJson(Map<String, dynamic> json) {
  return _Source.fromJson(json);
}

/// @nodoc
mixin _$Source {
  String get id => throw _privateConstructorUsedError;
  String get notebookId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get type =>
      throw _privateConstructorUsedError; // drive, file, url, youtube, audio, text, image
  DateTime get addedAt => throw _privateConstructorUsedError;
  String get content =>
      throw _privateConstructorUsedError; // raw text or transcript
  String? get summary => throw _privateConstructorUsedError;
  DateTime? get summaryGeneratedAt => throw _privateConstructorUsedError;
  String? get imageUrl =>
      throw _privateConstructorUsedError; // URL or base64 data URL for image sources
  String? get thumbnailUrl =>
      throw _privateConstructorUsedError; // Optional thumbnail for previews
  List<String> get tagIds => throw _privateConstructorUsedError;

  /// Serializes this Source to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Source
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SourceCopyWith<Source> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SourceCopyWith<$Res> {
  factory $SourceCopyWith(Source value, $Res Function(Source) then) =
      _$SourceCopyWithImpl<$Res, Source>;
  @useResult
  $Res call(
      {String id,
      String notebookId,
      String title,
      String type,
      DateTime addedAt,
      String content,
      String? summary,
      DateTime? summaryGeneratedAt,
      String? imageUrl,
      String? thumbnailUrl,
      List<String> tagIds});
}

/// @nodoc
class _$SourceCopyWithImpl<$Res, $Val extends Source>
    implements $SourceCopyWith<$Res> {
  _$SourceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Source
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? notebookId = null,
    Object? title = null,
    Object? type = null,
    Object? addedAt = null,
    Object? content = null,
    Object? summary = freezed,
    Object? summaryGeneratedAt = freezed,
    Object? imageUrl = freezed,
    Object? thumbnailUrl = freezed,
    Object? tagIds = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      notebookId: null == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      addedAt: null == addedAt
          ? _value.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      summary: freezed == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String?,
      summaryGeneratedAt: freezed == summaryGeneratedAt
          ? _value.summaryGeneratedAt
          : summaryGeneratedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      tagIds: null == tagIds
          ? _value.tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SourceImplCopyWith<$Res> implements $SourceCopyWith<$Res> {
  factory _$$SourceImplCopyWith(
          _$SourceImpl value, $Res Function(_$SourceImpl) then) =
      __$$SourceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String notebookId,
      String title,
      String type,
      DateTime addedAt,
      String content,
      String? summary,
      DateTime? summaryGeneratedAt,
      String? imageUrl,
      String? thumbnailUrl,
      List<String> tagIds});
}

/// @nodoc
class __$$SourceImplCopyWithImpl<$Res>
    extends _$SourceCopyWithImpl<$Res, _$SourceImpl>
    implements _$$SourceImplCopyWith<$Res> {
  __$$SourceImplCopyWithImpl(
      _$SourceImpl _value, $Res Function(_$SourceImpl) _then)
      : super(_value, _then);

  /// Create a copy of Source
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? notebookId = null,
    Object? title = null,
    Object? type = null,
    Object? addedAt = null,
    Object? content = null,
    Object? summary = freezed,
    Object? summaryGeneratedAt = freezed,
    Object? imageUrl = freezed,
    Object? thumbnailUrl = freezed,
    Object? tagIds = null,
  }) {
    return _then(_$SourceImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      notebookId: null == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      addedAt: null == addedAt
          ? _value.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      summary: freezed == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String?,
      summaryGeneratedAt: freezed == summaryGeneratedAt
          ? _value.summaryGeneratedAt
          : summaryGeneratedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      tagIds: null == tagIds
          ? _value._tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SourceImpl implements _Source {
  const _$SourceImpl(
      {required this.id,
      required this.notebookId,
      required this.title,
      required this.type,
      required this.addedAt,
      required this.content,
      this.summary,
      this.summaryGeneratedAt,
      this.imageUrl,
      this.thumbnailUrl,
      final List<String> tagIds = const []})
      : _tagIds = tagIds;

  factory _$SourceImpl.fromJson(Map<String, dynamic> json) =>
      _$$SourceImplFromJson(json);

  @override
  final String id;
  @override
  final String notebookId;
  @override
  final String title;
  @override
  final String type;
// drive, file, url, youtube, audio, text, image
  @override
  final DateTime addedAt;
  @override
  final String content;
// raw text or transcript
  @override
  final String? summary;
  @override
  final DateTime? summaryGeneratedAt;
  @override
  final String? imageUrl;
// URL or base64 data URL for image sources
  @override
  final String? thumbnailUrl;
// Optional thumbnail for previews
  final List<String> _tagIds;
// Optional thumbnail for previews
  @override
  @JsonKey()
  List<String> get tagIds {
    if (_tagIds is EqualUnmodifiableListView) return _tagIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tagIds);
  }

  @override
  String toString() {
    return 'Source(id: $id, notebookId: $notebookId, title: $title, type: $type, addedAt: $addedAt, content: $content, summary: $summary, summaryGeneratedAt: $summaryGeneratedAt, imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, tagIds: $tagIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SourceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.notebookId, notebookId) ||
                other.notebookId == notebookId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.addedAt, addedAt) || other.addedAt == addedAt) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.summaryGeneratedAt, summaryGeneratedAt) ||
                other.summaryGeneratedAt == summaryGeneratedAt) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            const DeepCollectionEquality().equals(other._tagIds, _tagIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      notebookId,
      title,
      type,
      addedAt,
      content,
      summary,
      summaryGeneratedAt,
      imageUrl,
      thumbnailUrl,
      const DeepCollectionEquality().hash(_tagIds));

  /// Create a copy of Source
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SourceImplCopyWith<_$SourceImpl> get copyWith =>
      __$$SourceImplCopyWithImpl<_$SourceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SourceImplToJson(
      this,
    );
  }
}

abstract class _Source implements Source {
  const factory _Source(
      {required final String id,
      required final String notebookId,
      required final String title,
      required final String type,
      required final DateTime addedAt,
      required final String content,
      final String? summary,
      final DateTime? summaryGeneratedAt,
      final String? imageUrl,
      final String? thumbnailUrl,
      final List<String> tagIds}) = _$SourceImpl;

  factory _Source.fromJson(Map<String, dynamic> json) = _$SourceImpl.fromJson;

  @override
  String get id;
  @override
  String get notebookId;
  @override
  String get title;
  @override
  String get type; // drive, file, url, youtube, audio, text, image
  @override
  DateTime get addedAt;
  @override
  String get content; // raw text or transcript
  @override
  String? get summary;
  @override
  DateTime? get summaryGeneratedAt;
  @override
  String? get imageUrl; // URL or base64 data URL for image sources
  @override
  String? get thumbnailUrl; // Optional thumbnail for previews
  @override
  List<String> get tagIds;

  /// Create a copy of Source
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SourceImplCopyWith<_$SourceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
