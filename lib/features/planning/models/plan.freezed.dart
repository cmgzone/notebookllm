// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DesignNote _$DesignNoteFromJson(Map<String, dynamic> json) {
  return _DesignNote.fromJson(json);
}

/// @nodoc
mixin _$DesignNote {
  String get id => throw _privateConstructorUsedError;
  String get planId => throw _privateConstructorUsedError;
  List<String> get requirementIds => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this DesignNote to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DesignNote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DesignNoteCopyWith<DesignNote> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DesignNoteCopyWith<$Res> {
  factory $DesignNoteCopyWith(
          DesignNote value, $Res Function(DesignNote) then) =
      _$DesignNoteCopyWithImpl<$Res, DesignNote>;
  @useResult
  $Res call(
      {String id,
      String planId,
      List<String> requirementIds,
      String content,
      DateTime createdAt});
}

/// @nodoc
class _$DesignNoteCopyWithImpl<$Res, $Val extends DesignNote>
    implements $DesignNoteCopyWith<$Res> {
  _$DesignNoteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DesignNote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? requirementIds = null,
    Object? content = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      requirementIds: null == requirementIds
          ? _value.requirementIds
          : requirementIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DesignNoteImplCopyWith<$Res>
    implements $DesignNoteCopyWith<$Res> {
  factory _$$DesignNoteImplCopyWith(
          _$DesignNoteImpl value, $Res Function(_$DesignNoteImpl) then) =
      __$$DesignNoteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String planId,
      List<String> requirementIds,
      String content,
      DateTime createdAt});
}

/// @nodoc
class __$$DesignNoteImplCopyWithImpl<$Res>
    extends _$DesignNoteCopyWithImpl<$Res, _$DesignNoteImpl>
    implements _$$DesignNoteImplCopyWith<$Res> {
  __$$DesignNoteImplCopyWithImpl(
      _$DesignNoteImpl _value, $Res Function(_$DesignNoteImpl) _then)
      : super(_value, _then);

  /// Create a copy of DesignNote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? requirementIds = null,
    Object? content = null,
    Object? createdAt = null,
  }) {
    return _then(_$DesignNoteImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      requirementIds: null == requirementIds
          ? _value._requirementIds
          : requirementIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DesignNoteImpl implements _DesignNote {
  const _$DesignNoteImpl(
      {required this.id,
      required this.planId,
      final List<String> requirementIds = const [],
      required this.content,
      required this.createdAt})
      : _requirementIds = requirementIds;

  factory _$DesignNoteImpl.fromJson(Map<String, dynamic> json) =>
      _$$DesignNoteImplFromJson(json);

  @override
  final String id;
  @override
  final String planId;
  final List<String> _requirementIds;
  @override
  @JsonKey()
  List<String> get requirementIds {
    if (_requirementIds is EqualUnmodifiableListView) return _requirementIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requirementIds);
  }

  @override
  final String content;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'DesignNote(id: $id, planId: $planId, requirementIds: $requirementIds, content: $content, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DesignNoteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            const DeepCollectionEquality()
                .equals(other._requirementIds, _requirementIds) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, planId,
      const DeepCollectionEquality().hash(_requirementIds), content, createdAt);

  /// Create a copy of DesignNote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DesignNoteImplCopyWith<_$DesignNoteImpl> get copyWith =>
      __$$DesignNoteImplCopyWithImpl<_$DesignNoteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DesignNoteImplToJson(
      this,
    );
  }
}

abstract class _DesignNote implements DesignNote {
  const factory _DesignNote(
      {required final String id,
      required final String planId,
      final List<String> requirementIds,
      required final String content,
      required final DateTime createdAt}) = _$DesignNoteImpl;

  factory _DesignNote.fromJson(Map<String, dynamic> json) =
      _$DesignNoteImpl.fromJson;

  @override
  String get id;
  @override
  String get planId;
  @override
  List<String> get requirementIds;
  @override
  String get content;
  @override
  DateTime get createdAt;

  /// Create a copy of DesignNote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DesignNoteImplCopyWith<_$DesignNoteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AgentAccess _$AgentAccessFromJson(Map<String, dynamic> json) {
  return _AgentAccess.fromJson(json);
}

/// @nodoc
mixin _$AgentAccess {
  String get id => throw _privateConstructorUsedError;
  String get planId => throw _privateConstructorUsedError;
  String get agentSessionId => throw _privateConstructorUsedError;
  String? get agentName => throw _privateConstructorUsedError;
  List<String> get permissions => throw _privateConstructorUsedError;
  DateTime get grantedAt => throw _privateConstructorUsedError;
  DateTime? get revokedAt => throw _privateConstructorUsedError;

  /// Serializes this AgentAccess to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgentAccess
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentAccessCopyWith<AgentAccess> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentAccessCopyWith<$Res> {
  factory $AgentAccessCopyWith(
          AgentAccess value, $Res Function(AgentAccess) then) =
      _$AgentAccessCopyWithImpl<$Res, AgentAccess>;
  @useResult
  $Res call(
      {String id,
      String planId,
      String agentSessionId,
      String? agentName,
      List<String> permissions,
      DateTime grantedAt,
      DateTime? revokedAt});
}

/// @nodoc
class _$AgentAccessCopyWithImpl<$Res, $Val extends AgentAccess>
    implements $AgentAccessCopyWith<$Res> {
  _$AgentAccessCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentAccess
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? agentSessionId = null,
    Object? agentName = freezed,
    Object? permissions = null,
    Object? grantedAt = null,
    Object? revokedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      agentSessionId: null == agentSessionId
          ? _value.agentSessionId
          : agentSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      permissions: null == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      grantedAt: null == grantedAt
          ? _value.grantedAt
          : grantedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      revokedAt: freezed == revokedAt
          ? _value.revokedAt
          : revokedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AgentAccessImplCopyWith<$Res>
    implements $AgentAccessCopyWith<$Res> {
  factory _$$AgentAccessImplCopyWith(
          _$AgentAccessImpl value, $Res Function(_$AgentAccessImpl) then) =
      __$$AgentAccessImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String planId,
      String agentSessionId,
      String? agentName,
      List<String> permissions,
      DateTime grantedAt,
      DateTime? revokedAt});
}

/// @nodoc
class __$$AgentAccessImplCopyWithImpl<$Res>
    extends _$AgentAccessCopyWithImpl<$Res, _$AgentAccessImpl>
    implements _$$AgentAccessImplCopyWith<$Res> {
  __$$AgentAccessImplCopyWithImpl(
      _$AgentAccessImpl _value, $Res Function(_$AgentAccessImpl) _then)
      : super(_value, _then);

  /// Create a copy of AgentAccess
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? agentSessionId = null,
    Object? agentName = freezed,
    Object? permissions = null,
    Object? grantedAt = null,
    Object? revokedAt = freezed,
  }) {
    return _then(_$AgentAccessImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      agentSessionId: null == agentSessionId
          ? _value.agentSessionId
          : agentSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      permissions: null == permissions
          ? _value._permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      grantedAt: null == grantedAt
          ? _value.grantedAt
          : grantedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      revokedAt: freezed == revokedAt
          ? _value.revokedAt
          : revokedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentAccessImpl implements _AgentAccess {
  const _$AgentAccessImpl(
      {required this.id,
      required this.planId,
      required this.agentSessionId,
      this.agentName,
      final List<String> permissions = const ['read'],
      required this.grantedAt,
      this.revokedAt})
      : _permissions = permissions;

  factory _$AgentAccessImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentAccessImplFromJson(json);

  @override
  final String id;
  @override
  final String planId;
  @override
  final String agentSessionId;
  @override
  final String? agentName;
  final List<String> _permissions;
  @override
  @JsonKey()
  List<String> get permissions {
    if (_permissions is EqualUnmodifiableListView) return _permissions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_permissions);
  }

  @override
  final DateTime grantedAt;
  @override
  final DateTime? revokedAt;

  @override
  String toString() {
    return 'AgentAccess(id: $id, planId: $planId, agentSessionId: $agentSessionId, agentName: $agentName, permissions: $permissions, grantedAt: $grantedAt, revokedAt: $revokedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentAccessImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.agentSessionId, agentSessionId) ||
                other.agentSessionId == agentSessionId) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            const DeepCollectionEquality()
                .equals(other._permissions, _permissions) &&
            (identical(other.grantedAt, grantedAt) ||
                other.grantedAt == grantedAt) &&
            (identical(other.revokedAt, revokedAt) ||
                other.revokedAt == revokedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      planId,
      agentSessionId,
      agentName,
      const DeepCollectionEquality().hash(_permissions),
      grantedAt,
      revokedAt);

  /// Create a copy of AgentAccess
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentAccessImplCopyWith<_$AgentAccessImpl> get copyWith =>
      __$$AgentAccessImplCopyWithImpl<_$AgentAccessImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentAccessImplToJson(
      this,
    );
  }
}

abstract class _AgentAccess implements AgentAccess {
  const factory _AgentAccess(
      {required final String id,
      required final String planId,
      required final String agentSessionId,
      final String? agentName,
      final List<String> permissions,
      required final DateTime grantedAt,
      final DateTime? revokedAt}) = _$AgentAccessImpl;

  factory _AgentAccess.fromJson(Map<String, dynamic> json) =
      _$AgentAccessImpl.fromJson;

  @override
  String get id;
  @override
  String get planId;
  @override
  String get agentSessionId;
  @override
  String? get agentName;
  @override
  List<String> get permissions;
  @override
  DateTime get grantedAt;
  @override
  DateTime? get revokedAt;

  /// Create a copy of AgentAccess
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentAccessImplCopyWith<_$AgentAccessImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Plan _$PlanFromJson(Map<String, dynamic> json) {
  return _Plan.fromJson(json);
}

/// @nodoc
mixin _$Plan {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  PlanStatus get status =>
      throw _privateConstructorUsedError; // Spec-driven structure (Requirements 4.1)
  List<Requirement> get requirements => throw _privateConstructorUsedError;
  List<DesignNote> get designNotes => throw _privateConstructorUsedError;
  List<PlanTask> get tasks =>
      throw _privateConstructorUsedError; // Access control (Requirements 7.1, 7.4)
  bool get isPrivate => throw _privateConstructorUsedError;
  List<AgentAccess> get sharedAgents =>
      throw _privateConstructorUsedError; // Social sharing fields
  bool get isPublic => throw _privateConstructorUsedError;
  int get viewCount => throw _privateConstructorUsedError;
  int get shareCount => throw _privateConstructorUsedError; // Metadata
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;

  /// Serializes this Plan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanCopyWith<Plan> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanCopyWith<$Res> {
  factory $PlanCopyWith(Plan value, $Res Function(Plan) then) =
      _$PlanCopyWithImpl<$Res, Plan>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String title,
      String description,
      PlanStatus status,
      List<Requirement> requirements,
      List<DesignNote> designNotes,
      List<PlanTask> tasks,
      bool isPrivate,
      List<AgentAccess> sharedAgents,
      bool isPublic,
      int viewCount,
      int shareCount,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime? completedAt});
}

/// @nodoc
class _$PlanCopyWithImpl<$Res, $Val extends Plan>
    implements $PlanCopyWith<$Res> {
  _$PlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? title = null,
    Object? description = null,
    Object? status = null,
    Object? requirements = null,
    Object? designNotes = null,
    Object? tasks = null,
    Object? isPrivate = null,
    Object? sharedAgents = null,
    Object? isPublic = null,
    Object? viewCount = null,
    Object? shareCount = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? completedAt = freezed,
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PlanStatus,
      requirements: null == requirements
          ? _value.requirements
          : requirements // ignore: cast_nullable_to_non_nullable
              as List<Requirement>,
      designNotes: null == designNotes
          ? _value.designNotes
          : designNotes // ignore: cast_nullable_to_non_nullable
              as List<DesignNote>,
      tasks: null == tasks
          ? _value.tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<PlanTask>,
      isPrivate: null == isPrivate
          ? _value.isPrivate
          : isPrivate // ignore: cast_nullable_to_non_nullable
              as bool,
      sharedAgents: null == sharedAgents
          ? _value.sharedAgents
          : sharedAgents // ignore: cast_nullable_to_non_nullable
              as List<AgentAccess>,
      isPublic: null == isPublic
          ? _value.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      viewCount: null == viewCount
          ? _value.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      shareCount: null == shareCount
          ? _value.shareCount
          : shareCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlanImplCopyWith<$Res> implements $PlanCopyWith<$Res> {
  factory _$$PlanImplCopyWith(
          _$PlanImpl value, $Res Function(_$PlanImpl) then) =
      __$$PlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String title,
      String description,
      PlanStatus status,
      List<Requirement> requirements,
      List<DesignNote> designNotes,
      List<PlanTask> tasks,
      bool isPrivate,
      List<AgentAccess> sharedAgents,
      bool isPublic,
      int viewCount,
      int shareCount,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime? completedAt});
}

/// @nodoc
class __$$PlanImplCopyWithImpl<$Res>
    extends _$PlanCopyWithImpl<$Res, _$PlanImpl>
    implements _$$PlanImplCopyWith<$Res> {
  __$$PlanImplCopyWithImpl(_$PlanImpl _value, $Res Function(_$PlanImpl) _then)
      : super(_value, _then);

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? title = null,
    Object? description = null,
    Object? status = null,
    Object? requirements = null,
    Object? designNotes = null,
    Object? tasks = null,
    Object? isPrivate = null,
    Object? sharedAgents = null,
    Object? isPublic = null,
    Object? viewCount = null,
    Object? shareCount = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? completedAt = freezed,
  }) {
    return _then(_$PlanImpl(
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PlanStatus,
      requirements: null == requirements
          ? _value._requirements
          : requirements // ignore: cast_nullable_to_non_nullable
              as List<Requirement>,
      designNotes: null == designNotes
          ? _value._designNotes
          : designNotes // ignore: cast_nullable_to_non_nullable
              as List<DesignNote>,
      tasks: null == tasks
          ? _value._tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<PlanTask>,
      isPrivate: null == isPrivate
          ? _value.isPrivate
          : isPrivate // ignore: cast_nullable_to_non_nullable
              as bool,
      sharedAgents: null == sharedAgents
          ? _value._sharedAgents
          : sharedAgents // ignore: cast_nullable_to_non_nullable
              as List<AgentAccess>,
      isPublic: null == isPublic
          ? _value.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      viewCount: null == viewCount
          ? _value.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      shareCount: null == shareCount
          ? _value.shareCount
          : shareCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlanImpl extends _Plan {
  const _$PlanImpl(
      {required this.id,
      required this.userId,
      required this.title,
      this.description = '',
      this.status = PlanStatus.draft,
      final List<Requirement> requirements = const [],
      final List<DesignNote> designNotes = const [],
      final List<PlanTask> tasks = const [],
      this.isPrivate = true,
      final List<AgentAccess> sharedAgents = const [],
      this.isPublic = false,
      this.viewCount = 0,
      this.shareCount = 0,
      required this.createdAt,
      required this.updatedAt,
      this.completedAt})
      : _requirements = requirements,
        _designNotes = designNotes,
        _tasks = tasks,
        _sharedAgents = sharedAgents,
        super._();

  factory _$PlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanImplFromJson(json);

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
  @JsonKey()
  final PlanStatus status;
// Spec-driven structure (Requirements 4.1)
  final List<Requirement> _requirements;
// Spec-driven structure (Requirements 4.1)
  @override
  @JsonKey()
  List<Requirement> get requirements {
    if (_requirements is EqualUnmodifiableListView) return _requirements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requirements);
  }

  final List<DesignNote> _designNotes;
  @override
  @JsonKey()
  List<DesignNote> get designNotes {
    if (_designNotes is EqualUnmodifiableListView) return _designNotes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_designNotes);
  }

  final List<PlanTask> _tasks;
  @override
  @JsonKey()
  List<PlanTask> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

// Access control (Requirements 7.1, 7.4)
  @override
  @JsonKey()
  final bool isPrivate;
  final List<AgentAccess> _sharedAgents;
  @override
  @JsonKey()
  List<AgentAccess> get sharedAgents {
    if (_sharedAgents is EqualUnmodifiableListView) return _sharedAgents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sharedAgents);
  }

// Social sharing fields
  @override
  @JsonKey()
  final bool isPublic;
  @override
  @JsonKey()
  final int viewCount;
  @override
  @JsonKey()
  final int shareCount;
// Metadata
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? completedAt;

  @override
  String toString() {
    return 'Plan(id: $id, userId: $userId, title: $title, description: $description, status: $status, requirements: $requirements, designNotes: $designNotes, tasks: $tasks, isPrivate: $isPrivate, sharedAgents: $sharedAgents, isPublic: $isPublic, viewCount: $viewCount, shareCount: $shareCount, createdAt: $createdAt, updatedAt: $updatedAt, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._requirements, _requirements) &&
            const DeepCollectionEquality()
                .equals(other._designNotes, _designNotes) &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            (identical(other.isPrivate, isPrivate) ||
                other.isPrivate == isPrivate) &&
            const DeepCollectionEquality()
                .equals(other._sharedAgents, _sharedAgents) &&
            (identical(other.isPublic, isPublic) ||
                other.isPublic == isPublic) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            (identical(other.shareCount, shareCount) ||
                other.shareCount == shareCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      title,
      description,
      status,
      const DeepCollectionEquality().hash(_requirements),
      const DeepCollectionEquality().hash(_designNotes),
      const DeepCollectionEquality().hash(_tasks),
      isPrivate,
      const DeepCollectionEquality().hash(_sharedAgents),
      isPublic,
      viewCount,
      shareCount,
      createdAt,
      updatedAt,
      completedAt);

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      __$$PlanImplCopyWithImpl<_$PlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanImplToJson(
      this,
    );
  }
}

abstract class _Plan extends Plan {
  const factory _Plan(
      {required final String id,
      required final String userId,
      required final String title,
      final String description,
      final PlanStatus status,
      final List<Requirement> requirements,
      final List<DesignNote> designNotes,
      final List<PlanTask> tasks,
      final bool isPrivate,
      final List<AgentAccess> sharedAgents,
      final bool isPublic,
      final int viewCount,
      final int shareCount,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      final DateTime? completedAt}) = _$PlanImpl;
  const _Plan._() : super._();

  factory _Plan.fromJson(Map<String, dynamic> json) = _$PlanImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get title;
  @override
  String get description;
  @override
  PlanStatus get status; // Spec-driven structure (Requirements 4.1)
  @override
  List<Requirement> get requirements;
  @override
  List<DesignNote> get designNotes;
  @override
  List<PlanTask> get tasks; // Access control (Requirements 7.1, 7.4)
  @override
  bool get isPrivate;
  @override
  List<AgentAccess> get sharedAgents; // Social sharing fields
  @override
  bool get isPublic;
  @override
  int get viewCount;
  @override
  int get shareCount; // Metadata
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  DateTime? get completedAt;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
