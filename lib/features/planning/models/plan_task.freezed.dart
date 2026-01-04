// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan_task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

StatusChange _$StatusChangeFromJson(Map<String, dynamic> json) {
  return _StatusChange.fromJson(json);
}

/// @nodoc
mixin _$StatusChange {
  TaskStatus get status => throw _privateConstructorUsedError;
  DateTime get changedAt => throw _privateConstructorUsedError;
  String get changedBy =>
      throw _privateConstructorUsedError; // userId or agentId
  String? get reason => throw _privateConstructorUsedError;

  /// Serializes this StatusChange to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StatusChange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StatusChangeCopyWith<StatusChange> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StatusChangeCopyWith<$Res> {
  factory $StatusChangeCopyWith(
          StatusChange value, $Res Function(StatusChange) then) =
      _$StatusChangeCopyWithImpl<$Res, StatusChange>;
  @useResult
  $Res call(
      {TaskStatus status,
      DateTime changedAt,
      String changedBy,
      String? reason});
}

/// @nodoc
class _$StatusChangeCopyWithImpl<$Res, $Val extends StatusChange>
    implements $StatusChangeCopyWith<$Res> {
  _$StatusChangeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StatusChange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? changedAt = null,
    Object? changedBy = null,
    Object? reason = freezed,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      changedAt: null == changedAt
          ? _value.changedAt
          : changedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      changedBy: null == changedBy
          ? _value.changedBy
          : changedBy // ignore: cast_nullable_to_non_nullable
              as String,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StatusChangeImplCopyWith<$Res>
    implements $StatusChangeCopyWith<$Res> {
  factory _$$StatusChangeImplCopyWith(
          _$StatusChangeImpl value, $Res Function(_$StatusChangeImpl) then) =
      __$$StatusChangeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {TaskStatus status,
      DateTime changedAt,
      String changedBy,
      String? reason});
}

/// @nodoc
class __$$StatusChangeImplCopyWithImpl<$Res>
    extends _$StatusChangeCopyWithImpl<$Res, _$StatusChangeImpl>
    implements _$$StatusChangeImplCopyWith<$Res> {
  __$$StatusChangeImplCopyWithImpl(
      _$StatusChangeImpl _value, $Res Function(_$StatusChangeImpl) _then)
      : super(_value, _then);

  /// Create a copy of StatusChange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? changedAt = null,
    Object? changedBy = null,
    Object? reason = freezed,
  }) {
    return _then(_$StatusChangeImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      changedAt: null == changedAt
          ? _value.changedAt
          : changedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      changedBy: null == changedBy
          ? _value.changedBy
          : changedBy // ignore: cast_nullable_to_non_nullable
              as String,
      reason: freezed == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StatusChangeImpl implements _StatusChange {
  const _$StatusChangeImpl(
      {required this.status,
      required this.changedAt,
      required this.changedBy,
      this.reason});

  factory _$StatusChangeImpl.fromJson(Map<String, dynamic> json) =>
      _$$StatusChangeImplFromJson(json);

  @override
  final TaskStatus status;
  @override
  final DateTime changedAt;
  @override
  final String changedBy;
// userId or agentId
  @override
  final String? reason;

  @override
  String toString() {
    return 'StatusChange(status: $status, changedAt: $changedAt, changedBy: $changedBy, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StatusChangeImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.changedAt, changedAt) ||
                other.changedAt == changedAt) &&
            (identical(other.changedBy, changedBy) ||
                other.changedBy == changedBy) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, status, changedAt, changedBy, reason);

  /// Create a copy of StatusChange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StatusChangeImplCopyWith<_$StatusChangeImpl> get copyWith =>
      __$$StatusChangeImplCopyWithImpl<_$StatusChangeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StatusChangeImplToJson(
      this,
    );
  }
}

abstract class _StatusChange implements StatusChange {
  const factory _StatusChange(
      {required final TaskStatus status,
      required final DateTime changedAt,
      required final String changedBy,
      final String? reason}) = _$StatusChangeImpl;

  factory _StatusChange.fromJson(Map<String, dynamic> json) =
      _$StatusChangeImpl.fromJson;

  @override
  TaskStatus get status;
  @override
  DateTime get changedAt;
  @override
  String get changedBy; // userId or agentId
  @override
  String? get reason;

  /// Create a copy of StatusChange
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StatusChangeImplCopyWith<_$StatusChangeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AgentOutput _$AgentOutputFromJson(Map<String, dynamic> json) {
  return _AgentOutput.fromJson(json);
}

/// @nodoc
mixin _$AgentOutput {
  String get id => throw _privateConstructorUsedError;
  String get taskId => throw _privateConstructorUsedError;
  String? get agentSessionId => throw _privateConstructorUsedError;
  String? get agentName => throw _privateConstructorUsedError;
  String get outputType =>
      throw _privateConstructorUsedError; // 'comment', 'code', 'file', 'completion'
  String get content => throw _privateConstructorUsedError;
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this AgentOutput to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgentOutput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentOutputCopyWith<AgentOutput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentOutputCopyWith<$Res> {
  factory $AgentOutputCopyWith(
          AgentOutput value, $Res Function(AgentOutput) then) =
      _$AgentOutputCopyWithImpl<$Res, AgentOutput>;
  @useResult
  $Res call(
      {String id,
      String taskId,
      String? agentSessionId,
      String? agentName,
      String outputType,
      String content,
      Map<String, dynamic> metadata,
      DateTime createdAt});
}

/// @nodoc
class _$AgentOutputCopyWithImpl<$Res, $Val extends AgentOutput>
    implements $AgentOutputCopyWith<$Res> {
  _$AgentOutputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentOutput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? taskId = null,
    Object? agentSessionId = freezed,
    Object? agentName = freezed,
    Object? outputType = null,
    Object? content = null,
    Object? metadata = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      agentSessionId: freezed == agentSessionId
          ? _value.agentSessionId
          : agentSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      outputType: null == outputType
          ? _value.outputType
          : outputType // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      metadata: null == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AgentOutputImplCopyWith<$Res>
    implements $AgentOutputCopyWith<$Res> {
  factory _$$AgentOutputImplCopyWith(
          _$AgentOutputImpl value, $Res Function(_$AgentOutputImpl) then) =
      __$$AgentOutputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String taskId,
      String? agentSessionId,
      String? agentName,
      String outputType,
      String content,
      Map<String, dynamic> metadata,
      DateTime createdAt});
}

/// @nodoc
class __$$AgentOutputImplCopyWithImpl<$Res>
    extends _$AgentOutputCopyWithImpl<$Res, _$AgentOutputImpl>
    implements _$$AgentOutputImplCopyWith<$Res> {
  __$$AgentOutputImplCopyWithImpl(
      _$AgentOutputImpl _value, $Res Function(_$AgentOutputImpl) _then)
      : super(_value, _then);

  /// Create a copy of AgentOutput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? taskId = null,
    Object? agentSessionId = freezed,
    Object? agentName = freezed,
    Object? outputType = null,
    Object? content = null,
    Object? metadata = null,
    Object? createdAt = null,
  }) {
    return _then(_$AgentOutputImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      agentSessionId: freezed == agentSessionId
          ? _value.agentSessionId
          : agentSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      agentName: freezed == agentName
          ? _value.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String?,
      outputType: null == outputType
          ? _value.outputType
          : outputType // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      metadata: null == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentOutputImpl implements _AgentOutput {
  const _$AgentOutputImpl(
      {required this.id,
      required this.taskId,
      this.agentSessionId,
      this.agentName,
      required this.outputType,
      required this.content,
      final Map<String, dynamic> metadata = const {},
      required this.createdAt})
      : _metadata = metadata;

  factory _$AgentOutputImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentOutputImplFromJson(json);

  @override
  final String id;
  @override
  final String taskId;
  @override
  final String? agentSessionId;
  @override
  final String? agentName;
  @override
  final String outputType;
// 'comment', 'code', 'file', 'completion'
  @override
  final String content;
  final Map<String, dynamic> _metadata;
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'AgentOutput(id: $id, taskId: $taskId, agentSessionId: $agentSessionId, agentName: $agentName, outputType: $outputType, content: $content, metadata: $metadata, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentOutputImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.agentSessionId, agentSessionId) ||
                other.agentSessionId == agentSessionId) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.outputType, outputType) ||
                other.outputType == outputType) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      taskId,
      agentSessionId,
      agentName,
      outputType,
      content,
      const DeepCollectionEquality().hash(_metadata),
      createdAt);

  /// Create a copy of AgentOutput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentOutputImplCopyWith<_$AgentOutputImpl> get copyWith =>
      __$$AgentOutputImplCopyWithImpl<_$AgentOutputImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentOutputImplToJson(
      this,
    );
  }
}

abstract class _AgentOutput implements AgentOutput {
  const factory _AgentOutput(
      {required final String id,
      required final String taskId,
      final String? agentSessionId,
      final String? agentName,
      required final String outputType,
      required final String content,
      final Map<String, dynamic> metadata,
      required final DateTime createdAt}) = _$AgentOutputImpl;

  factory _AgentOutput.fromJson(Map<String, dynamic> json) =
      _$AgentOutputImpl.fromJson;

  @override
  String get id;
  @override
  String get taskId;
  @override
  String? get agentSessionId;
  @override
  String? get agentName;
  @override
  String get outputType; // 'comment', 'code', 'file', 'completion'
  @override
  String get content;
  @override
  Map<String, dynamic> get metadata;
  @override
  DateTime get createdAt;

  /// Create a copy of AgentOutput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentOutputImplCopyWith<_$AgentOutputImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlanTask _$PlanTaskFromJson(Map<String, dynamic> json) {
  return _PlanTask.fromJson(json);
}

/// @nodoc
mixin _$PlanTask {
  String get id => throw _privateConstructorUsedError;
  String get planId => throw _privateConstructorUsedError;
  String? get parentTaskId =>
      throw _privateConstructorUsedError; // For sub-tasks
  List<String> get requirementIds =>
      throw _privateConstructorUsedError; // Links to requirements (4.4)
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  TaskStatus get status => throw _privateConstructorUsedError;
  TaskPriority get priority =>
      throw _privateConstructorUsedError; // Agent tracking
  String? get assignedAgentId => throw _privateConstructorUsedError;
  List<AgentOutput> get agentOutputs => throw _privateConstructorUsedError;
  int get timeSpentMinutes =>
      throw _privateConstructorUsedError; // Status tracking (Requirements 3.2)
  List<StatusChange> get statusHistory => throw _privateConstructorUsedError;
  String? get blockingReason =>
      throw _privateConstructorUsedError; // Required when status is blocked (3.6)
// Hierarchy
  List<PlanTask> get subTasks =>
      throw _privateConstructorUsedError; // Timestamps
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;

  /// Serializes this PlanTask to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanTaskCopyWith<PlanTask> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanTaskCopyWith<$Res> {
  factory $PlanTaskCopyWith(PlanTask value, $Res Function(PlanTask) then) =
      _$PlanTaskCopyWithImpl<$Res, PlanTask>;
  @useResult
  $Res call(
      {String id,
      String planId,
      String? parentTaskId,
      List<String> requirementIds,
      String title,
      String description,
      TaskStatus status,
      TaskPriority priority,
      String? assignedAgentId,
      List<AgentOutput> agentOutputs,
      int timeSpentMinutes,
      List<StatusChange> statusHistory,
      String? blockingReason,
      List<PlanTask> subTasks,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime? completedAt});
}

/// @nodoc
class _$PlanTaskCopyWithImpl<$Res, $Val extends PlanTask>
    implements $PlanTaskCopyWith<$Res> {
  _$PlanTaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanTask
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? parentTaskId = freezed,
    Object? requirementIds = null,
    Object? title = null,
    Object? description = null,
    Object? status = null,
    Object? priority = null,
    Object? assignedAgentId = freezed,
    Object? agentOutputs = null,
    Object? timeSpentMinutes = null,
    Object? statusHistory = null,
    Object? blockingReason = freezed,
    Object? subTasks = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? completedAt = freezed,
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
      parentTaskId: freezed == parentTaskId
          ? _value.parentTaskId
          : parentTaskId // ignore: cast_nullable_to_non_nullable
              as String?,
      requirementIds: null == requirementIds
          ? _value.requirementIds
          : requirementIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
              as TaskStatus,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as TaskPriority,
      assignedAgentId: freezed == assignedAgentId
          ? _value.assignedAgentId
          : assignedAgentId // ignore: cast_nullable_to_non_nullable
              as String?,
      agentOutputs: null == agentOutputs
          ? _value.agentOutputs
          : agentOutputs // ignore: cast_nullable_to_non_nullable
              as List<AgentOutput>,
      timeSpentMinutes: null == timeSpentMinutes
          ? _value.timeSpentMinutes
          : timeSpentMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      statusHistory: null == statusHistory
          ? _value.statusHistory
          : statusHistory // ignore: cast_nullable_to_non_nullable
              as List<StatusChange>,
      blockingReason: freezed == blockingReason
          ? _value.blockingReason
          : blockingReason // ignore: cast_nullable_to_non_nullable
              as String?,
      subTasks: null == subTasks
          ? _value.subTasks
          : subTasks // ignore: cast_nullable_to_non_nullable
              as List<PlanTask>,
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
abstract class _$$PlanTaskImplCopyWith<$Res>
    implements $PlanTaskCopyWith<$Res> {
  factory _$$PlanTaskImplCopyWith(
          _$PlanTaskImpl value, $Res Function(_$PlanTaskImpl) then) =
      __$$PlanTaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String planId,
      String? parentTaskId,
      List<String> requirementIds,
      String title,
      String description,
      TaskStatus status,
      TaskPriority priority,
      String? assignedAgentId,
      List<AgentOutput> agentOutputs,
      int timeSpentMinutes,
      List<StatusChange> statusHistory,
      String? blockingReason,
      List<PlanTask> subTasks,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime? completedAt});
}

/// @nodoc
class __$$PlanTaskImplCopyWithImpl<$Res>
    extends _$PlanTaskCopyWithImpl<$Res, _$PlanTaskImpl>
    implements _$$PlanTaskImplCopyWith<$Res> {
  __$$PlanTaskImplCopyWithImpl(
      _$PlanTaskImpl _value, $Res Function(_$PlanTaskImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanTask
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? parentTaskId = freezed,
    Object? requirementIds = null,
    Object? title = null,
    Object? description = null,
    Object? status = null,
    Object? priority = null,
    Object? assignedAgentId = freezed,
    Object? agentOutputs = null,
    Object? timeSpentMinutes = null,
    Object? statusHistory = null,
    Object? blockingReason = freezed,
    Object? subTasks = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? completedAt = freezed,
  }) {
    return _then(_$PlanTaskImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      parentTaskId: freezed == parentTaskId
          ? _value.parentTaskId
          : parentTaskId // ignore: cast_nullable_to_non_nullable
              as String?,
      requirementIds: null == requirementIds
          ? _value._requirementIds
          : requirementIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
              as TaskStatus,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as TaskPriority,
      assignedAgentId: freezed == assignedAgentId
          ? _value.assignedAgentId
          : assignedAgentId // ignore: cast_nullable_to_non_nullable
              as String?,
      agentOutputs: null == agentOutputs
          ? _value._agentOutputs
          : agentOutputs // ignore: cast_nullable_to_non_nullable
              as List<AgentOutput>,
      timeSpentMinutes: null == timeSpentMinutes
          ? _value.timeSpentMinutes
          : timeSpentMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      statusHistory: null == statusHistory
          ? _value._statusHistory
          : statusHistory // ignore: cast_nullable_to_non_nullable
              as List<StatusChange>,
      blockingReason: freezed == blockingReason
          ? _value.blockingReason
          : blockingReason // ignore: cast_nullable_to_non_nullable
              as String?,
      subTasks: null == subTasks
          ? _value._subTasks
          : subTasks // ignore: cast_nullable_to_non_nullable
              as List<PlanTask>,
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
class _$PlanTaskImpl extends _PlanTask {
  const _$PlanTaskImpl(
      {required this.id,
      required this.planId,
      this.parentTaskId,
      final List<String> requirementIds = const [],
      required this.title,
      this.description = '',
      this.status = TaskStatus.notStarted,
      this.priority = TaskPriority.medium,
      this.assignedAgentId,
      final List<AgentOutput> agentOutputs = const [],
      this.timeSpentMinutes = 0,
      final List<StatusChange> statusHistory = const [],
      this.blockingReason,
      final List<PlanTask> subTasks = const [],
      required this.createdAt,
      required this.updatedAt,
      this.completedAt})
      : _requirementIds = requirementIds,
        _agentOutputs = agentOutputs,
        _statusHistory = statusHistory,
        _subTasks = subTasks,
        super._();

  factory _$PlanTaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanTaskImplFromJson(json);

  @override
  final String id;
  @override
  final String planId;
  @override
  final String? parentTaskId;
// For sub-tasks
  final List<String> _requirementIds;
// For sub-tasks
  @override
  @JsonKey()
  List<String> get requirementIds {
    if (_requirementIds is EqualUnmodifiableListView) return _requirementIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requirementIds);
  }

// Links to requirements (4.4)
  @override
  final String title;
  @override
  @JsonKey()
  final String description;
  @override
  @JsonKey()
  final TaskStatus status;
  @override
  @JsonKey()
  final TaskPriority priority;
// Agent tracking
  @override
  final String? assignedAgentId;
  final List<AgentOutput> _agentOutputs;
  @override
  @JsonKey()
  List<AgentOutput> get agentOutputs {
    if (_agentOutputs is EqualUnmodifiableListView) return _agentOutputs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_agentOutputs);
  }

  @override
  @JsonKey()
  final int timeSpentMinutes;
// Status tracking (Requirements 3.2)
  final List<StatusChange> _statusHistory;
// Status tracking (Requirements 3.2)
  @override
  @JsonKey()
  List<StatusChange> get statusHistory {
    if (_statusHistory is EqualUnmodifiableListView) return _statusHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_statusHistory);
  }

  @override
  final String? blockingReason;
// Required when status is blocked (3.6)
// Hierarchy
  final List<PlanTask> _subTasks;
// Required when status is blocked (3.6)
// Hierarchy
  @override
  @JsonKey()
  List<PlanTask> get subTasks {
    if (_subTasks is EqualUnmodifiableListView) return _subTasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subTasks);
  }

// Timestamps
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? completedAt;

  @override
  String toString() {
    return 'PlanTask(id: $id, planId: $planId, parentTaskId: $parentTaskId, requirementIds: $requirementIds, title: $title, description: $description, status: $status, priority: $priority, assignedAgentId: $assignedAgentId, agentOutputs: $agentOutputs, timeSpentMinutes: $timeSpentMinutes, statusHistory: $statusHistory, blockingReason: $blockingReason, subTasks: $subTasks, createdAt: $createdAt, updatedAt: $updatedAt, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanTaskImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.parentTaskId, parentTaskId) ||
                other.parentTaskId == parentTaskId) &&
            const DeepCollectionEquality()
                .equals(other._requirementIds, _requirementIds) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.assignedAgentId, assignedAgentId) ||
                other.assignedAgentId == assignedAgentId) &&
            const DeepCollectionEquality()
                .equals(other._agentOutputs, _agentOutputs) &&
            (identical(other.timeSpentMinutes, timeSpentMinutes) ||
                other.timeSpentMinutes == timeSpentMinutes) &&
            const DeepCollectionEquality()
                .equals(other._statusHistory, _statusHistory) &&
            (identical(other.blockingReason, blockingReason) ||
                other.blockingReason == blockingReason) &&
            const DeepCollectionEquality().equals(other._subTasks, _subTasks) &&
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
      planId,
      parentTaskId,
      const DeepCollectionEquality().hash(_requirementIds),
      title,
      description,
      status,
      priority,
      assignedAgentId,
      const DeepCollectionEquality().hash(_agentOutputs),
      timeSpentMinutes,
      const DeepCollectionEquality().hash(_statusHistory),
      blockingReason,
      const DeepCollectionEquality().hash(_subTasks),
      createdAt,
      updatedAt,
      completedAt);

  /// Create a copy of PlanTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanTaskImplCopyWith<_$PlanTaskImpl> get copyWith =>
      __$$PlanTaskImplCopyWithImpl<_$PlanTaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanTaskImplToJson(
      this,
    );
  }
}

abstract class _PlanTask extends PlanTask {
  const factory _PlanTask(
      {required final String id,
      required final String planId,
      final String? parentTaskId,
      final List<String> requirementIds,
      required final String title,
      final String description,
      final TaskStatus status,
      final TaskPriority priority,
      final String? assignedAgentId,
      final List<AgentOutput> agentOutputs,
      final int timeSpentMinutes,
      final List<StatusChange> statusHistory,
      final String? blockingReason,
      final List<PlanTask> subTasks,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      final DateTime? completedAt}) = _$PlanTaskImpl;
  const _PlanTask._() : super._();

  factory _PlanTask.fromJson(Map<String, dynamic> json) =
      _$PlanTaskImpl.fromJson;

  @override
  String get id;
  @override
  String get planId;
  @override
  String? get parentTaskId; // For sub-tasks
  @override
  List<String> get requirementIds; // Links to requirements (4.4)
  @override
  String get title;
  @override
  String get description;
  @override
  TaskStatus get status;
  @override
  TaskPriority get priority; // Agent tracking
  @override
  String? get assignedAgentId;
  @override
  List<AgentOutput> get agentOutputs;
  @override
  int get timeSpentMinutes; // Status tracking (Requirements 3.2)
  @override
  List<StatusChange> get statusHistory;
  @override
  String? get blockingReason; // Required when status is blocked (3.6)
// Hierarchy
  @override
  List<PlanTask> get subTasks; // Timestamps
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  DateTime? get completedAt;

  /// Create a copy of PlanTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanTaskImplCopyWith<_$PlanTaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
