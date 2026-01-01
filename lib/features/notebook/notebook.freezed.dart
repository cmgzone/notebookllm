// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notebook.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Notebook _$NotebookFromJson(Map<String, dynamic> json) {
  return _Notebook.fromJson(json);
}

/// @nodoc
mixin _$Notebook {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get coverImage =>
      throw _privateConstructorUsedError; // Base64 encoded image or URL
  int get sourceCount => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt =>
      throw _privateConstructorUsedError; // Agent notebook fields (Requirements 1.4, 4.1)
  bool get isAgentNotebook => throw _privateConstructorUsedError;
  String? get agentSessionId => throw _privateConstructorUsedError;
  String? get agentName => throw _privateConstructorUsedError;
  String? get agentIdentifier => throw _privateConstructorUsedError;
  String get agentStatus => throw _privateConstructorUsedError;

  /// Serializes this Notebook to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Notebook
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotebookCopyWith<Notebook> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotebookCopyWith<$Res> {
  factory $NotebookCopyWith(Notebook value, $Res Function(Notebook) then) =
      _$NotebookCopyWithImpl<$Res, Notebook>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String title,
      String description,
      String? coverImage,
      int sourceCount,
      DateTime createdAt,
      DateTime updatedAt,
      bool isAgentNotebook,
      String? agentSessionId,
      String? agentName,
      String? agentIdentifier,
      String agentStatus});
}

/// @nodoc
class _$NotebookCopyWithImpl<$Res, $Val extends Notebook>
    implements $NotebookCopyWith<$Res> {
  _$NotebookCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Notebook
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? title = null,
    Object? description = null,
    Object? coverImage = freezed,
    Object? sourceCount = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? isAgentNotebook = null,
    Object? agentSessionId = freezed,
    Object? agentName = freezed,
    Object? agentIdentifier = freezed,
    Object? agentStatus = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      coverImage: freezed == coverImage
          ? _value.coverImage
          : coverImage // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceCount: null == sourceCount
          ? _value.sourceCount
          : sourceCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isAgentNotebook: null == isAgentNotebook
          ? _value.isAgentNotebook
          : isAgentNotebook // ignore: cast_nullable_to_non_nullable
              as bool,
      agentSessionId: freezed == agentSessionId
          ? _value.agentSessionId
          : agentSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      agentIdentifier: freezed == agentIdentifier
          ? _value.agentIdentifier
          : agentIdentifier // ignore: cast_nullable_to_non_nullable
              as String?,
      agentStatus: null == agentStatus
          ? _value.agentStatus
          : agentStatus // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NotebookImplCopyWith<$Res>
    implements $NotebookCopyWith<$Res> {
  factory _$$NotebookImplCopyWith(
          _$NotebookImpl value, $Res Function(_$NotebookImpl) then) =
      __$$NotebookImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String title,
      String description,
      String? coverImage,
      int sourceCount,
      DateTime createdAt,
      DateTime updatedAt,
      bool isAgentNotebook,
      String? agentSessionId,
      String? agentName,
      String? agentIdentifier,
      String agentStatus});
}

/// @nodoc
class __$$NotebookImplCopyWithImpl<$Res>
    extends _$NotebookCopyWithImpl<$Res, _$NotebookImpl>
    implements _$$NotebookImplCopyWith<$Res> {
  __$$NotebookImplCopyWithImpl(
      _$NotebookImpl _value, $Res Function(_$NotebookImpl) _then)
      : super(_value, _then);

  /// Create a copy of Notebook
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? title = null,
    Object? description = null,
    Object? coverImage = freezed,
    Object? sourceCount = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? isAgentNotebook = null,
    Object? agentSessionId = freezed,
    Object? agentName = freezed,
    Object? agentIdentifier = freezed,
    Object? agentStatus = null,
  }) {
    return _then(_$NotebookImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      coverImage: freezed == coverImage
          ? _value.coverImage
          : coverImage // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceCount: null == sourceCount
          ? _value.sourceCount
          : sourceCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isAgentNotebook: null == isAgentNotebook
          ? _value.isAgentNotebook
          : isAgentNotebook // ignore: cast_nullable_to_non_nullable
              as bool,
      agentSessionId: freezed == agentSessionId
          ? _value.agentSessionId
          : agentSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      agentIdentifier: freezed == agentIdentifier
          ? _value.agentIdentifier
          : agentIdentifier // ignore: cast_nullable_to_non_nullable
              as String?,
      agentStatus: null == agentStatus
          ? _value.agentStatus
          : agentStatus // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NotebookImpl implements _Notebook {
  const _$NotebookImpl(
      {required this.id,
      required this.userId,
      required this.title,
      this.description = '',
      this.coverImage,
      required this.sourceCount,
      required this.createdAt,
      required this.updatedAt,
      this.isAgentNotebook = false,
      this.agentSessionId,
      this.agentName,
      this.agentIdentifier,
      this.agentStatus = 'active'});

  factory _$NotebookImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotebookImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String title;
  @override
  @JsonKey()
  final String description;
  @override
  final String? coverImage;
// Base64 encoded image or URL
  @override
  final int sourceCount;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
// Agent notebook fields (Requirements 1.4, 4.1)
  @override
  @JsonKey()
  final bool isAgentNotebook;
  @override
  final String? agentSessionId;
  @override
  final String? agentName;
  @override
  final String? agentIdentifier;
  @override
  @JsonKey()
  final String agentStatus;

  @override
  String toString() {
    return 'Notebook(id: $id, userId: $userId, title: $title, description: $description, coverImage: $coverImage, sourceCount: $sourceCount, createdAt: $createdAt, updatedAt: $updatedAt, isAgentNotebook: $isAgentNotebook, agentSessionId: $agentSessionId, agentName: $agentName, agentIdentifier: $agentIdentifier, agentStatus: $agentStatus)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotebookImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.coverImage, coverImage) ||
                other.coverImage == coverImage) &&
            (identical(other.sourceCount, sourceCount) ||
                other.sourceCount == sourceCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.isAgentNotebook, isAgentNotebook) ||
                other.isAgentNotebook == isAgentNotebook) &&
            (identical(other.agentSessionId, agentSessionId) ||
                other.agentSessionId == agentSessionId) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.agentIdentifier, agentIdentifier) ||
                other.agentIdentifier == agentIdentifier) &&
            (identical(other.agentStatus, agentStatus) ||
                other.agentStatus == agentStatus));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      title,
      description,
      coverImage,
      sourceCount,
      createdAt,
      updatedAt,
      isAgentNotebook,
      agentSessionId,
      agentName,
      agentIdentifier,
      agentStatus);

  /// Create a copy of Notebook
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotebookImplCopyWith<_$NotebookImpl> get copyWith =>
      __$$NotebookImplCopyWithImpl<_$NotebookImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotebookImplToJson(
      this,
    );
  }
}

abstract class _Notebook implements Notebook {
  const factory _Notebook(
      {required final String id,
      required final String userId,
      required final String title,
      final String description,
      final String? coverImage,
      required final int sourceCount,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      final bool isAgentNotebook,
      final String? agentSessionId,
      final String? agentName,
      final String? agentIdentifier,
      final String agentStatus}) = _$NotebookImpl;

  factory _Notebook.fromJson(Map<String, dynamic> json) =
      _$NotebookImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get title;
  @override
  String get description;
  @override
  String? get coverImage; // Base64 encoded image or URL
  @override
  int get sourceCount;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt; // Agent notebook fields (Requirements 1.4, 4.1)
  @override
  bool get isAgentNotebook;
  @override
  String? get agentSessionId;
  @override
  String? get agentName;
  @override
  String? get agentIdentifier;
  @override
  String get agentStatus;

  /// Create a copy of Notebook
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotebookImplCopyWith<_$NotebookImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
