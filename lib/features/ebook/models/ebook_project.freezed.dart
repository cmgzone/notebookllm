// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ebook_project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EbookProject _$EbookProjectFromJson(Map<String, dynamic> json) {
  return _EbookProject.fromJson(json);
}

/// @nodoc
mixin _$EbookProject {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get topic => throw _privateConstructorUsedError;
  String get targetAudience => throw _privateConstructorUsedError;
  BrandingConfig get branding => throw _privateConstructorUsedError;
  List<EbookChapter> get chapters => throw _privateConstructorUsedError;
  EbookStatus get status => throw _privateConstructorUsedError;
  String get selectedModel => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  String? get coverImageUrl => throw _privateConstructorUsedError;
  String? get notebookId => throw _privateConstructorUsedError;
  List<String> get chapterAudioUrls => throw _privateConstructorUsedError;
  String get currentPhase =>
      throw _privateConstructorUsedError; // Deep Research settings
  bool get useDeepResearch => throw _privateConstructorUsedError;
  ImageSourceType get imageSource => throw _privateConstructorUsedError;
  String? get deepResearchSummary => throw _privateConstructorUsedError;
  List<String> get webSearchedImages => throw _privateConstructorUsedError;

  /// Serializes this EbookProject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EbookProject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EbookProjectCopyWith<EbookProject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EbookProjectCopyWith<$Res> {
  factory $EbookProjectCopyWith(
          EbookProject value, $Res Function(EbookProject) then) =
      _$EbookProjectCopyWithImpl<$Res, EbookProject>;
  @useResult
  $Res call(
      {String id,
      String title,
      String topic,
      String targetAudience,
      BrandingConfig branding,
      List<EbookChapter> chapters,
      EbookStatus status,
      String selectedModel,
      DateTime createdAt,
      DateTime updatedAt,
      String? coverImageUrl,
      String? notebookId,
      List<String> chapterAudioUrls,
      String currentPhase,
      bool useDeepResearch,
      ImageSourceType imageSource,
      String? deepResearchSummary,
      List<String> webSearchedImages});

  $BrandingConfigCopyWith<$Res> get branding;
}

/// @nodoc
class _$EbookProjectCopyWithImpl<$Res, $Val extends EbookProject>
    implements $EbookProjectCopyWith<$Res> {
  _$EbookProjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EbookProject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? topic = null,
    Object? targetAudience = null,
    Object? branding = null,
    Object? chapters = null,
    Object? status = null,
    Object? selectedModel = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? coverImageUrl = freezed,
    Object? notebookId = freezed,
    Object? chapterAudioUrls = null,
    Object? currentPhase = null,
    Object? useDeepResearch = null,
    Object? imageSource = null,
    Object? deepResearchSummary = freezed,
    Object? webSearchedImages = null,
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
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      targetAudience: null == targetAudience
          ? _value.targetAudience
          : targetAudience // ignore: cast_nullable_to_non_nullable
              as String,
      branding: null == branding
          ? _value.branding
          : branding // ignore: cast_nullable_to_non_nullable
              as BrandingConfig,
      chapters: null == chapters
          ? _value.chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<EbookChapter>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as EbookStatus,
      selectedModel: null == selectedModel
          ? _value.selectedModel
          : selectedModel // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      coverImageUrl: freezed == coverImageUrl
          ? _value.coverImageUrl
          : coverImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      notebookId: freezed == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String?,
      chapterAudioUrls: null == chapterAudioUrls
          ? _value.chapterAudioUrls
          : chapterAudioUrls // ignore: cast_nullable_to_non_nullable
              as List<String>,
      currentPhase: null == currentPhase
          ? _value.currentPhase
          : currentPhase // ignore: cast_nullable_to_non_nullable
              as String,
      useDeepResearch: null == useDeepResearch
          ? _value.useDeepResearch
          : useDeepResearch // ignore: cast_nullable_to_non_nullable
              as bool,
      imageSource: null == imageSource
          ? _value.imageSource
          : imageSource // ignore: cast_nullable_to_non_nullable
              as ImageSourceType,
      deepResearchSummary: freezed == deepResearchSummary
          ? _value.deepResearchSummary
          : deepResearchSummary // ignore: cast_nullable_to_non_nullable
              as String?,
      webSearchedImages: null == webSearchedImages
          ? _value.webSearchedImages
          : webSearchedImages // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }

  /// Create a copy of EbookProject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BrandingConfigCopyWith<$Res> get branding {
    return $BrandingConfigCopyWith<$Res>(_value.branding, (value) {
      return _then(_value.copyWith(branding: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EbookProjectImplCopyWith<$Res>
    implements $EbookProjectCopyWith<$Res> {
  factory _$$EbookProjectImplCopyWith(
          _$EbookProjectImpl value, $Res Function(_$EbookProjectImpl) then) =
      __$$EbookProjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String topic,
      String targetAudience,
      BrandingConfig branding,
      List<EbookChapter> chapters,
      EbookStatus status,
      String selectedModel,
      DateTime createdAt,
      DateTime updatedAt,
      String? coverImageUrl,
      String? notebookId,
      List<String> chapterAudioUrls,
      String currentPhase,
      bool useDeepResearch,
      ImageSourceType imageSource,
      String? deepResearchSummary,
      List<String> webSearchedImages});

  @override
  $BrandingConfigCopyWith<$Res> get branding;
}

/// @nodoc
class __$$EbookProjectImplCopyWithImpl<$Res>
    extends _$EbookProjectCopyWithImpl<$Res, _$EbookProjectImpl>
    implements _$$EbookProjectImplCopyWith<$Res> {
  __$$EbookProjectImplCopyWithImpl(
      _$EbookProjectImpl _value, $Res Function(_$EbookProjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of EbookProject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? topic = null,
    Object? targetAudience = null,
    Object? branding = null,
    Object? chapters = null,
    Object? status = null,
    Object? selectedModel = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? coverImageUrl = freezed,
    Object? notebookId = freezed,
    Object? chapterAudioUrls = null,
    Object? currentPhase = null,
    Object? useDeepResearch = null,
    Object? imageSource = null,
    Object? deepResearchSummary = freezed,
    Object? webSearchedImages = null,
  }) {
    return _then(_$EbookProjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      targetAudience: null == targetAudience
          ? _value.targetAudience
          : targetAudience // ignore: cast_nullable_to_non_nullable
              as String,
      branding: null == branding
          ? _value.branding
          : branding // ignore: cast_nullable_to_non_nullable
              as BrandingConfig,
      chapters: null == chapters
          ? _value._chapters
          : chapters // ignore: cast_nullable_to_non_nullable
              as List<EbookChapter>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as EbookStatus,
      selectedModel: null == selectedModel
          ? _value.selectedModel
          : selectedModel // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      coverImageUrl: freezed == coverImageUrl
          ? _value.coverImageUrl
          : coverImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      notebookId: freezed == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String?,
      chapterAudioUrls: null == chapterAudioUrls
          ? _value._chapterAudioUrls
          : chapterAudioUrls // ignore: cast_nullable_to_non_nullable
              as List<String>,
      currentPhase: null == currentPhase
          ? _value.currentPhase
          : currentPhase // ignore: cast_nullable_to_non_nullable
              as String,
      useDeepResearch: null == useDeepResearch
          ? _value.useDeepResearch
          : useDeepResearch // ignore: cast_nullable_to_non_nullable
              as bool,
      imageSource: null == imageSource
          ? _value.imageSource
          : imageSource // ignore: cast_nullable_to_non_nullable
              as ImageSourceType,
      deepResearchSummary: freezed == deepResearchSummary
          ? _value.deepResearchSummary
          : deepResearchSummary // ignore: cast_nullable_to_non_nullable
              as String?,
      webSearchedImages: null == webSearchedImages
          ? _value._webSearchedImages
          : webSearchedImages // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EbookProjectImpl extends _EbookProject {
  const _$EbookProjectImpl(
      {required this.id,
      required this.title,
      required this.topic,
      required this.targetAudience,
      required this.branding,
      final List<EbookChapter> chapters = const [],
      this.status = EbookStatus.draft,
      required this.selectedModel,
      required this.createdAt,
      required this.updatedAt,
      this.coverImageUrl,
      this.notebookId,
      final List<String> chapterAudioUrls = const [],
      this.currentPhase = 'Starting...',
      this.useDeepResearch = false,
      this.imageSource = ImageSourceType.aiGenerated,
      this.deepResearchSummary,
      final List<String> webSearchedImages = const []})
      : _chapters = chapters,
        _chapterAudioUrls = chapterAudioUrls,
        _webSearchedImages = webSearchedImages,
        super._();

  factory _$EbookProjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$EbookProjectImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String topic;
  @override
  final String targetAudience;
  @override
  final BrandingConfig branding;
  final List<EbookChapter> _chapters;
  @override
  @JsonKey()
  List<EbookChapter> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

  @override
  @JsonKey()
  final EbookStatus status;
  @override
  final String selectedModel;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String? coverImageUrl;
  @override
  final String? notebookId;
  final List<String> _chapterAudioUrls;
  @override
  @JsonKey()
  List<String> get chapterAudioUrls {
    if (_chapterAudioUrls is EqualUnmodifiableListView)
      return _chapterAudioUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapterAudioUrls);
  }

  @override
  @JsonKey()
  final String currentPhase;
// Deep Research settings
  @override
  @JsonKey()
  final bool useDeepResearch;
  @override
  @JsonKey()
  final ImageSourceType imageSource;
  @override
  final String? deepResearchSummary;
  final List<String> _webSearchedImages;
  @override
  @JsonKey()
  List<String> get webSearchedImages {
    if (_webSearchedImages is EqualUnmodifiableListView)
      return _webSearchedImages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_webSearchedImages);
  }

  @override
  String toString() {
    return 'EbookProject(id: $id, title: $title, topic: $topic, targetAudience: $targetAudience, branding: $branding, chapters: $chapters, status: $status, selectedModel: $selectedModel, createdAt: $createdAt, updatedAt: $updatedAt, coverImageUrl: $coverImageUrl, notebookId: $notebookId, chapterAudioUrls: $chapterAudioUrls, currentPhase: $currentPhase, useDeepResearch: $useDeepResearch, imageSource: $imageSource, deepResearchSummary: $deepResearchSummary, webSearchedImages: $webSearchedImages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EbookProjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.targetAudience, targetAudience) ||
                other.targetAudience == targetAudience) &&
            (identical(other.branding, branding) ||
                other.branding == branding) &&
            const DeepCollectionEquality().equals(other._chapters, _chapters) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.selectedModel, selectedModel) ||
                other.selectedModel == selectedModel) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.coverImageUrl, coverImageUrl) ||
                other.coverImageUrl == coverImageUrl) &&
            (identical(other.notebookId, notebookId) ||
                other.notebookId == notebookId) &&
            const DeepCollectionEquality()
                .equals(other._chapterAudioUrls, _chapterAudioUrls) &&
            (identical(other.currentPhase, currentPhase) ||
                other.currentPhase == currentPhase) &&
            (identical(other.useDeepResearch, useDeepResearch) ||
                other.useDeepResearch == useDeepResearch) &&
            (identical(other.imageSource, imageSource) ||
                other.imageSource == imageSource) &&
            (identical(other.deepResearchSummary, deepResearchSummary) ||
                other.deepResearchSummary == deepResearchSummary) &&
            const DeepCollectionEquality()
                .equals(other._webSearchedImages, _webSearchedImages));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      topic,
      targetAudience,
      branding,
      const DeepCollectionEquality().hash(_chapters),
      status,
      selectedModel,
      createdAt,
      updatedAt,
      coverImageUrl,
      notebookId,
      const DeepCollectionEquality().hash(_chapterAudioUrls),
      currentPhase,
      useDeepResearch,
      imageSource,
      deepResearchSummary,
      const DeepCollectionEquality().hash(_webSearchedImages));

  /// Create a copy of EbookProject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EbookProjectImplCopyWith<_$EbookProjectImpl> get copyWith =>
      __$$EbookProjectImplCopyWithImpl<_$EbookProjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EbookProjectImplToJson(
      this,
    );
  }
}

abstract class _EbookProject extends EbookProject {
  const factory _EbookProject(
      {required final String id,
      required final String title,
      required final String topic,
      required final String targetAudience,
      required final BrandingConfig branding,
      final List<EbookChapter> chapters,
      final EbookStatus status,
      required final String selectedModel,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      final String? coverImageUrl,
      final String? notebookId,
      final List<String> chapterAudioUrls,
      final String currentPhase,
      final bool useDeepResearch,
      final ImageSourceType imageSource,
      final String? deepResearchSummary,
      final List<String> webSearchedImages}) = _$EbookProjectImpl;
  const _EbookProject._() : super._();

  factory _EbookProject.fromJson(Map<String, dynamic> json) =
      _$EbookProjectImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get topic;
  @override
  String get targetAudience;
  @override
  BrandingConfig get branding;
  @override
  List<EbookChapter> get chapters;
  @override
  EbookStatus get status;
  @override
  String get selectedModel;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  String? get coverImageUrl;
  @override
  String? get notebookId;
  @override
  List<String> get chapterAudioUrls;
  @override
  String get currentPhase; // Deep Research settings
  @override
  bool get useDeepResearch;
  @override
  ImageSourceType get imageSource;
  @override
  String? get deepResearchSummary;
  @override
  List<String> get webSearchedImages;

  /// Create a copy of EbookProject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EbookProjectImplCopyWith<_$EbookProjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
