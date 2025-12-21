// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ebook_chapter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EbookChapter _$EbookChapterFromJson(Map<String, dynamic> json) {
  return _EbookChapter.fromJson(json);
}

/// @nodoc
mixin _$EbookChapter {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError; // Markdown content
  List<EbookImage> get images => throw _privateConstructorUsedError;
  int get orderIndex => throw _privateConstructorUsedError;
  bool get isGenerating => throw _privateConstructorUsedError;

  /// Serializes this EbookChapter to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EbookChapter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EbookChapterCopyWith<EbookChapter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EbookChapterCopyWith<$Res> {
  factory $EbookChapterCopyWith(
          EbookChapter value, $Res Function(EbookChapter) then) =
      _$EbookChapterCopyWithImpl<$Res, EbookChapter>;
  @useResult
  $Res call(
      {String id,
      String title,
      String content,
      List<EbookImage> images,
      int orderIndex,
      bool isGenerating});
}

/// @nodoc
class _$EbookChapterCopyWithImpl<$Res, $Val extends EbookChapter>
    implements $EbookChapterCopyWith<$Res> {
  _$EbookChapterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EbookChapter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? content = null,
    Object? images = null,
    Object? orderIndex = null,
    Object? isGenerating = null,
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
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<EbookImage>,
      orderIndex: null == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      isGenerating: null == isGenerating
          ? _value.isGenerating
          : isGenerating // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EbookChapterImplCopyWith<$Res>
    implements $EbookChapterCopyWith<$Res> {
  factory _$$EbookChapterImplCopyWith(
          _$EbookChapterImpl value, $Res Function(_$EbookChapterImpl) then) =
      __$$EbookChapterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String content,
      List<EbookImage> images,
      int orderIndex,
      bool isGenerating});
}

/// @nodoc
class __$$EbookChapterImplCopyWithImpl<$Res>
    extends _$EbookChapterCopyWithImpl<$Res, _$EbookChapterImpl>
    implements _$$EbookChapterImplCopyWith<$Res> {
  __$$EbookChapterImplCopyWithImpl(
      _$EbookChapterImpl _value, $Res Function(_$EbookChapterImpl) _then)
      : super(_value, _then);

  /// Create a copy of EbookChapter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? content = null,
    Object? images = null,
    Object? orderIndex = null,
    Object? isGenerating = null,
  }) {
    return _then(_$EbookChapterImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<EbookImage>,
      orderIndex: null == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      isGenerating: null == isGenerating
          ? _value.isGenerating
          : isGenerating // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EbookChapterImpl extends _EbookChapter {
  const _$EbookChapterImpl(
      {required this.id,
      required this.title,
      required this.content,
      final List<EbookImage> images = const [],
      required this.orderIndex,
      this.isGenerating = false})
      : _images = images,
        super._();

  factory _$EbookChapterImpl.fromJson(Map<String, dynamic> json) =>
      _$$EbookChapterImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String content;
// Markdown content
  final List<EbookImage> _images;
// Markdown content
  @override
  @JsonKey()
  List<EbookImage> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  final int orderIndex;
  @override
  @JsonKey()
  final bool isGenerating;

  @override
  String toString() {
    return 'EbookChapter(id: $id, title: $title, content: $content, images: $images, orderIndex: $orderIndex, isGenerating: $isGenerating)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EbookChapterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.isGenerating, isGenerating) ||
                other.isGenerating == isGenerating));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, content,
      const DeepCollectionEquality().hash(_images), orderIndex, isGenerating);

  /// Create a copy of EbookChapter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EbookChapterImplCopyWith<_$EbookChapterImpl> get copyWith =>
      __$$EbookChapterImplCopyWithImpl<_$EbookChapterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EbookChapterImplToJson(
      this,
    );
  }
}

abstract class _EbookChapter extends EbookChapter {
  const factory _EbookChapter(
      {required final String id,
      required final String title,
      required final String content,
      final List<EbookImage> images,
      required final int orderIndex,
      final bool isGenerating}) = _$EbookChapterImpl;
  const _EbookChapter._() : super._();

  factory _EbookChapter.fromJson(Map<String, dynamic> json) =
      _$EbookChapterImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get content; // Markdown content
  @override
  List<EbookImage> get images;
  @override
  int get orderIndex;
  @override
  bool get isGenerating;

  /// Create a copy of EbookChapter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EbookChapterImplCopyWith<_$EbookChapterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
