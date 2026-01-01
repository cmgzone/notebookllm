// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Message _$MessageFromJson(Map<String, dynamic> json) {
  return _Message.fromJson(json);
}

/// @nodoc
mixin _$Message {
  String get id => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  bool get isUser => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  List<Citation> get citations => throw _privateConstructorUsedError;
  List<String> get suggestedQuestions => throw _privateConstructorUsedError;
  List<SourceSuggestion> get relatedSources =>
      throw _privateConstructorUsedError;
  String? get imageUrl =>
      throw _privateConstructorUsedError; // Local file path or URL for attached image
  bool get isDeepSearch =>
      throw _privateConstructorUsedError; // Whether this used deep search
  bool get isWebBrowsing =>
      throw _privateConstructorUsedError; // Whether this is a web browsing message
  String? get webBrowsingStatus =>
      throw _privateConstructorUsedError; // Current status of web browsing
  List<String> get webBrowsingScreenshots =>
      throw _privateConstructorUsedError; // Screenshots from browsing
  List<String> get webBrowsingSources => throw _privateConstructorUsedError;

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessageCopyWith<Message> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageCopyWith<$Res> {
  factory $MessageCopyWith(Message value, $Res Function(Message) then) =
      _$MessageCopyWithImpl<$Res, Message>;
  @useResult
  $Res call(
      {String id,
      String text,
      bool isUser,
      DateTime timestamp,
      List<Citation> citations,
      List<String> suggestedQuestions,
      List<SourceSuggestion> relatedSources,
      String? imageUrl,
      bool isDeepSearch,
      bool isWebBrowsing,
      String? webBrowsingStatus,
      List<String> webBrowsingScreenshots,
      List<String> webBrowsingSources});
}

/// @nodoc
class _$MessageCopyWithImpl<$Res, $Val extends Message>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? isUser = null,
    Object? timestamp = null,
    Object? citations = null,
    Object? suggestedQuestions = null,
    Object? relatedSources = null,
    Object? imageUrl = freezed,
    Object? isDeepSearch = null,
    Object? isWebBrowsing = null,
    Object? webBrowsingStatus = freezed,
    Object? webBrowsingScreenshots = null,
    Object? webBrowsingSources = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      isUser: null == isUser
          ? _value.isUser
          : isUser // ignore: cast_nullable_to_non_nullable
              as bool,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      citations: null == citations
          ? _value.citations
          : citations // ignore: cast_nullable_to_non_nullable
              as List<Citation>,
      suggestedQuestions: null == suggestedQuestions
          ? _value.suggestedQuestions
          : suggestedQuestions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      relatedSources: null == relatedSources
          ? _value.relatedSources
          : relatedSources // ignore: cast_nullable_to_non_nullable
              as List<SourceSuggestion>,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isDeepSearch: null == isDeepSearch
          ? _value.isDeepSearch
          : isDeepSearch // ignore: cast_nullable_to_non_nullable
              as bool,
      isWebBrowsing: null == isWebBrowsing
          ? _value.isWebBrowsing
          : isWebBrowsing // ignore: cast_nullable_to_non_nullable
              as bool,
      webBrowsingStatus: freezed == webBrowsingStatus
          ? _value.webBrowsingStatus
          : webBrowsingStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      webBrowsingScreenshots: null == webBrowsingScreenshots
          ? _value.webBrowsingScreenshots
          : webBrowsingScreenshots // ignore: cast_nullable_to_non_nullable
              as List<String>,
      webBrowsingSources: null == webBrowsingSources
          ? _value.webBrowsingSources
          : webBrowsingSources // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MessageImplCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$$MessageImplCopyWith(
          _$MessageImpl value, $Res Function(_$MessageImpl) then) =
      __$$MessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String text,
      bool isUser,
      DateTime timestamp,
      List<Citation> citations,
      List<String> suggestedQuestions,
      List<SourceSuggestion> relatedSources,
      String? imageUrl,
      bool isDeepSearch,
      bool isWebBrowsing,
      String? webBrowsingStatus,
      List<String> webBrowsingScreenshots,
      List<String> webBrowsingSources});
}

/// @nodoc
class __$$MessageImplCopyWithImpl<$Res>
    extends _$MessageCopyWithImpl<$Res, _$MessageImpl>
    implements _$$MessageImplCopyWith<$Res> {
  __$$MessageImplCopyWithImpl(
      _$MessageImpl _value, $Res Function(_$MessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? isUser = null,
    Object? timestamp = null,
    Object? citations = null,
    Object? suggestedQuestions = null,
    Object? relatedSources = null,
    Object? imageUrl = freezed,
    Object? isDeepSearch = null,
    Object? isWebBrowsing = null,
    Object? webBrowsingStatus = freezed,
    Object? webBrowsingScreenshots = null,
    Object? webBrowsingSources = null,
  }) {
    return _then(_$MessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      isUser: null == isUser
          ? _value.isUser
          : isUser // ignore: cast_nullable_to_non_nullable
              as bool,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      citations: null == citations
          ? _value._citations
          : citations // ignore: cast_nullable_to_non_nullable
              as List<Citation>,
      suggestedQuestions: null == suggestedQuestions
          ? _value._suggestedQuestions
          : suggestedQuestions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      relatedSources: null == relatedSources
          ? _value._relatedSources
          : relatedSources // ignore: cast_nullable_to_non_nullable
              as List<SourceSuggestion>,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isDeepSearch: null == isDeepSearch
          ? _value.isDeepSearch
          : isDeepSearch // ignore: cast_nullable_to_non_nullable
              as bool,
      isWebBrowsing: null == isWebBrowsing
          ? _value.isWebBrowsing
          : isWebBrowsing // ignore: cast_nullable_to_non_nullable
              as bool,
      webBrowsingStatus: freezed == webBrowsingStatus
          ? _value.webBrowsingStatus
          : webBrowsingStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      webBrowsingScreenshots: null == webBrowsingScreenshots
          ? _value._webBrowsingScreenshots
          : webBrowsingScreenshots // ignore: cast_nullable_to_non_nullable
              as List<String>,
      webBrowsingSources: null == webBrowsingSources
          ? _value._webBrowsingSources
          : webBrowsingSources // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MessageImpl implements _Message {
  const _$MessageImpl(
      {required this.id,
      required this.text,
      required this.isUser,
      required this.timestamp,
      final List<Citation> citations = const [],
      final List<String> suggestedQuestions = const [],
      final List<SourceSuggestion> relatedSources = const [],
      this.imageUrl,
      this.isDeepSearch = false,
      this.isWebBrowsing = false,
      this.webBrowsingStatus,
      final List<String> webBrowsingScreenshots = const [],
      final List<String> webBrowsingSources = const []})
      : _citations = citations,
        _suggestedQuestions = suggestedQuestions,
        _relatedSources = relatedSources,
        _webBrowsingScreenshots = webBrowsingScreenshots,
        _webBrowsingSources = webBrowsingSources;

  factory _$MessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessageImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final bool isUser;
  @override
  final DateTime timestamp;
  final List<Citation> _citations;
  @override
  @JsonKey()
  List<Citation> get citations {
    if (_citations is EqualUnmodifiableListView) return _citations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_citations);
  }

  final List<String> _suggestedQuestions;
  @override
  @JsonKey()
  List<String> get suggestedQuestions {
    if (_suggestedQuestions is EqualUnmodifiableListView)
      return _suggestedQuestions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_suggestedQuestions);
  }

  final List<SourceSuggestion> _relatedSources;
  @override
  @JsonKey()
  List<SourceSuggestion> get relatedSources {
    if (_relatedSources is EqualUnmodifiableListView) return _relatedSources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_relatedSources);
  }

  @override
  final String? imageUrl;
// Local file path or URL for attached image
  @override
  @JsonKey()
  final bool isDeepSearch;
// Whether this used deep search
  @override
  @JsonKey()
  final bool isWebBrowsing;
// Whether this is a web browsing message
  @override
  final String? webBrowsingStatus;
// Current status of web browsing
  final List<String> _webBrowsingScreenshots;
// Current status of web browsing
  @override
  @JsonKey()
  List<String> get webBrowsingScreenshots {
    if (_webBrowsingScreenshots is EqualUnmodifiableListView)
      return _webBrowsingScreenshots;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_webBrowsingScreenshots);
  }

// Screenshots from browsing
  final List<String> _webBrowsingSources;
// Screenshots from browsing
  @override
  @JsonKey()
  List<String> get webBrowsingSources {
    if (_webBrowsingSources is EqualUnmodifiableListView)
      return _webBrowsingSources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_webBrowsingSources);
  }

  @override
  String toString() {
    return 'Message(id: $id, text: $text, isUser: $isUser, timestamp: $timestamp, citations: $citations, suggestedQuestions: $suggestedQuestions, relatedSources: $relatedSources, imageUrl: $imageUrl, isDeepSearch: $isDeepSearch, isWebBrowsing: $isWebBrowsing, webBrowsingStatus: $webBrowsingStatus, webBrowsingScreenshots: $webBrowsingScreenshots, webBrowsingSources: $webBrowsingSources)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.isUser, isUser) || other.isUser == isUser) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            const DeepCollectionEquality()
                .equals(other._citations, _citations) &&
            const DeepCollectionEquality()
                .equals(other._suggestedQuestions, _suggestedQuestions) &&
            const DeepCollectionEquality()
                .equals(other._relatedSources, _relatedSources) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.isDeepSearch, isDeepSearch) ||
                other.isDeepSearch == isDeepSearch) &&
            (identical(other.isWebBrowsing, isWebBrowsing) ||
                other.isWebBrowsing == isWebBrowsing) &&
            (identical(other.webBrowsingStatus, webBrowsingStatus) ||
                other.webBrowsingStatus == webBrowsingStatus) &&
            const DeepCollectionEquality().equals(
                other._webBrowsingScreenshots, _webBrowsingScreenshots) &&
            const DeepCollectionEquality()
                .equals(other._webBrowsingSources, _webBrowsingSources));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      text,
      isUser,
      timestamp,
      const DeepCollectionEquality().hash(_citations),
      const DeepCollectionEquality().hash(_suggestedQuestions),
      const DeepCollectionEquality().hash(_relatedSources),
      imageUrl,
      isDeepSearch,
      isWebBrowsing,
      webBrowsingStatus,
      const DeepCollectionEquality().hash(_webBrowsingScreenshots),
      const DeepCollectionEquality().hash(_webBrowsingSources));

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      __$$MessageImplCopyWithImpl<_$MessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MessageImplToJson(
      this,
    );
  }
}

abstract class _Message implements Message {
  const factory _Message(
      {required final String id,
      required final String text,
      required final bool isUser,
      required final DateTime timestamp,
      final List<Citation> citations,
      final List<String> suggestedQuestions,
      final List<SourceSuggestion> relatedSources,
      final String? imageUrl,
      final bool isDeepSearch,
      final bool isWebBrowsing,
      final String? webBrowsingStatus,
      final List<String> webBrowsingScreenshots,
      final List<String> webBrowsingSources}) = _$MessageImpl;

  factory _Message.fromJson(Map<String, dynamic> json) = _$MessageImpl.fromJson;

  @override
  String get id;
  @override
  String get text;
  @override
  bool get isUser;
  @override
  DateTime get timestamp;
  @override
  List<Citation> get citations;
  @override
  List<String> get suggestedQuestions;
  @override
  List<SourceSuggestion> get relatedSources;
  @override
  String? get imageUrl; // Local file path or URL for attached image
  @override
  bool get isDeepSearch; // Whether this used deep search
  @override
  bool get isWebBrowsing; // Whether this is a web browsing message
  @override
  String? get webBrowsingStatus; // Current status of web browsing
  @override
  List<String> get webBrowsingScreenshots; // Screenshots from browsing
  @override
  List<String> get webBrowsingSources;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Citation _$CitationFromJson(Map<String, dynamic> json) {
  return _Citation.fromJson(json);
}

/// @nodoc
mixin _$Citation {
  String get id => throw _privateConstructorUsedError;
  String get sourceId => throw _privateConstructorUsedError;
  String get snippet => throw _privateConstructorUsedError;
  int get start => throw _privateConstructorUsedError;
  int get end => throw _privateConstructorUsedError;

  /// Serializes this Citation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CitationCopyWith<Citation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CitationCopyWith<$Res> {
  factory $CitationCopyWith(Citation value, $Res Function(Citation) then) =
      _$CitationCopyWithImpl<$Res, Citation>;
  @useResult
  $Res call({String id, String sourceId, String snippet, int start, int end});
}

/// @nodoc
class _$CitationCopyWithImpl<$Res, $Val extends Citation>
    implements $CitationCopyWith<$Res> {
  _$CitationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceId = null,
    Object? snippet = null,
    Object? start = null,
    Object? end = null,
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
      snippet: null == snippet
          ? _value.snippet
          : snippet // ignore: cast_nullable_to_non_nullable
              as String,
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as int,
      end: null == end
          ? _value.end
          : end // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CitationImplCopyWith<$Res>
    implements $CitationCopyWith<$Res> {
  factory _$$CitationImplCopyWith(
          _$CitationImpl value, $Res Function(_$CitationImpl) then) =
      __$$CitationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String sourceId, String snippet, int start, int end});
}

/// @nodoc
class __$$CitationImplCopyWithImpl<$Res>
    extends _$CitationCopyWithImpl<$Res, _$CitationImpl>
    implements _$$CitationImplCopyWith<$Res> {
  __$$CitationImplCopyWithImpl(
      _$CitationImpl _value, $Res Function(_$CitationImpl) _then)
      : super(_value, _then);

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceId = null,
    Object? snippet = null,
    Object? start = null,
    Object? end = null,
  }) {
    return _then(_$CitationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sourceId: null == sourceId
          ? _value.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String,
      snippet: null == snippet
          ? _value.snippet
          : snippet // ignore: cast_nullable_to_non_nullable
              as String,
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as int,
      end: null == end
          ? _value.end
          : end // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CitationImpl implements _Citation {
  const _$CitationImpl(
      {required this.id,
      required this.sourceId,
      required this.snippet,
      required this.start,
      required this.end});

  factory _$CitationImpl.fromJson(Map<String, dynamic> json) =>
      _$$CitationImplFromJson(json);

  @override
  final String id;
  @override
  final String sourceId;
  @override
  final String snippet;
  @override
  final int start;
  @override
  final int end;

  @override
  String toString() {
    return 'Citation(id: $id, sourceId: $sourceId, snippet: $snippet, start: $start, end: $end)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CitationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.snippet, snippet) || other.snippet == snippet) &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, sourceId, snippet, start, end);

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CitationImplCopyWith<_$CitationImpl> get copyWith =>
      __$$CitationImplCopyWithImpl<_$CitationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CitationImplToJson(
      this,
    );
  }
}

abstract class _Citation implements Citation {
  const factory _Citation(
      {required final String id,
      required final String sourceId,
      required final String snippet,
      required final int start,
      required final int end}) = _$CitationImpl;

  factory _Citation.fromJson(Map<String, dynamic> json) =
      _$CitationImpl.fromJson;

  @override
  String get id;
  @override
  String get sourceId;
  @override
  String get snippet;
  @override
  int get start;
  @override
  int get end;

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CitationImplCopyWith<_$CitationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SourceSuggestion _$SourceSuggestionFromJson(Map<String, dynamic> json) {
  return _SourceSuggestion.fromJson(json);
}

/// @nodoc
mixin _$SourceSuggestion {
  String get title => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  String get type =>
      throw _privateConstructorUsedError; // 'youtube', 'article', etc.
  String? get thumbnailUrl => throw _privateConstructorUsedError;

  /// Serializes this SourceSuggestion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SourceSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SourceSuggestionCopyWith<SourceSuggestion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SourceSuggestionCopyWith<$Res> {
  factory $SourceSuggestionCopyWith(
          SourceSuggestion value, $Res Function(SourceSuggestion) then) =
      _$SourceSuggestionCopyWithImpl<$Res, SourceSuggestion>;
  @useResult
  $Res call({String title, String url, String type, String? thumbnailUrl});
}

/// @nodoc
class _$SourceSuggestionCopyWithImpl<$Res, $Val extends SourceSuggestion>
    implements $SourceSuggestionCopyWith<$Res> {
  _$SourceSuggestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SourceSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? url = null,
    Object? type = null,
    Object? thumbnailUrl = freezed,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SourceSuggestionImplCopyWith<$Res>
    implements $SourceSuggestionCopyWith<$Res> {
  factory _$$SourceSuggestionImplCopyWith(_$SourceSuggestionImpl value,
          $Res Function(_$SourceSuggestionImpl) then) =
      __$$SourceSuggestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, String url, String type, String? thumbnailUrl});
}

/// @nodoc
class __$$SourceSuggestionImplCopyWithImpl<$Res>
    extends _$SourceSuggestionCopyWithImpl<$Res, _$SourceSuggestionImpl>
    implements _$$SourceSuggestionImplCopyWith<$Res> {
  __$$SourceSuggestionImplCopyWithImpl(_$SourceSuggestionImpl _value,
      $Res Function(_$SourceSuggestionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SourceSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? url = null,
    Object? type = null,
    Object? thumbnailUrl = freezed,
  }) {
    return _then(_$SourceSuggestionImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SourceSuggestionImpl implements _SourceSuggestion {
  const _$SourceSuggestionImpl(
      {required this.title,
      required this.url,
      required this.type,
      this.thumbnailUrl});

  factory _$SourceSuggestionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SourceSuggestionImplFromJson(json);

  @override
  final String title;
  @override
  final String url;
  @override
  final String type;
// 'youtube', 'article', etc.
  @override
  final String? thumbnailUrl;

  @override
  String toString() {
    return 'SourceSuggestion(title: $title, url: $url, type: $type, thumbnailUrl: $thumbnailUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SourceSuggestionImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, url, type, thumbnailUrl);

  /// Create a copy of SourceSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SourceSuggestionImplCopyWith<_$SourceSuggestionImpl> get copyWith =>
      __$$SourceSuggestionImplCopyWithImpl<_$SourceSuggestionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SourceSuggestionImplToJson(
      this,
    );
  }
}

abstract class _SourceSuggestion implements SourceSuggestion {
  const factory _SourceSuggestion(
      {required final String title,
      required final String url,
      required final String type,
      final String? thumbnailUrl}) = _$SourceSuggestionImpl;

  factory _SourceSuggestion.fromJson(Map<String, dynamic> json) =
      _$SourceSuggestionImpl.fromJson;

  @override
  String get title;
  @override
  String get url;
  @override
  String get type; // 'youtube', 'article', etc.
  @override
  String? get thumbnailUrl;

  /// Create a copy of SourceSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SourceSuggestionImplCopyWith<_$SourceSuggestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
