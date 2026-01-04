// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'requirement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Requirement _$RequirementFromJson(Map<String, dynamic> json) {
  return _Requirement.fromJson(json);
}

/// @nodoc
mixin _$Requirement {
  String get id => throw _privateConstructorUsedError;
  String get planId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  EarsPattern get earsPattern => throw _privateConstructorUsedError;
  List<String> get acceptanceCriteria => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Requirement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Requirement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RequirementCopyWith<Requirement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RequirementCopyWith<$Res> {
  factory $RequirementCopyWith(
          Requirement value, $Res Function(Requirement) then) =
      _$RequirementCopyWithImpl<$Res, Requirement>;
  @useResult
  $Res call(
      {String id,
      String planId,
      String title,
      String description,
      EarsPattern earsPattern,
      List<String> acceptanceCriteria,
      int sortOrder,
      DateTime createdAt});
}

/// @nodoc
class _$RequirementCopyWithImpl<$Res, $Val extends Requirement>
    implements $RequirementCopyWith<$Res> {
  _$RequirementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Requirement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? title = null,
    Object? description = null,
    Object? earsPattern = null,
    Object? acceptanceCriteria = null,
    Object? sortOrder = null,
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
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      earsPattern: null == earsPattern
          ? _value.earsPattern
          : earsPattern // ignore: cast_nullable_to_non_nullable
              as EarsPattern,
      acceptanceCriteria: null == acceptanceCriteria
          ? _value.acceptanceCriteria
          : acceptanceCriteria // ignore: cast_nullable_to_non_nullable
              as List<String>,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RequirementImplCopyWith<$Res>
    implements $RequirementCopyWith<$Res> {
  factory _$$RequirementImplCopyWith(
          _$RequirementImpl value, $Res Function(_$RequirementImpl) then) =
      __$$RequirementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String planId,
      String title,
      String description,
      EarsPattern earsPattern,
      List<String> acceptanceCriteria,
      int sortOrder,
      DateTime createdAt});
}

/// @nodoc
class __$$RequirementImplCopyWithImpl<$Res>
    extends _$RequirementCopyWithImpl<$Res, _$RequirementImpl>
    implements _$$RequirementImplCopyWith<$Res> {
  __$$RequirementImplCopyWithImpl(
      _$RequirementImpl _value, $Res Function(_$RequirementImpl) _then)
      : super(_value, _then);

  /// Create a copy of Requirement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? title = null,
    Object? description = null,
    Object? earsPattern = null,
    Object? acceptanceCriteria = null,
    Object? sortOrder = null,
    Object? createdAt = null,
  }) {
    return _then(_$RequirementImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      earsPattern: null == earsPattern
          ? _value.earsPattern
          : earsPattern // ignore: cast_nullable_to_non_nullable
              as EarsPattern,
      acceptanceCriteria: null == acceptanceCriteria
          ? _value._acceptanceCriteria
          : acceptanceCriteria // ignore: cast_nullable_to_non_nullable
              as List<String>,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RequirementImpl extends _Requirement {
  const _$RequirementImpl(
      {required this.id,
      required this.planId,
      required this.title,
      this.description = '',
      this.earsPattern = EarsPattern.ubiquitous,
      final List<String> acceptanceCriteria = const [],
      this.sortOrder = 0,
      required this.createdAt})
      : _acceptanceCriteria = acceptanceCriteria,
        super._();

  factory _$RequirementImpl.fromJson(Map<String, dynamic> json) =>
      _$$RequirementImplFromJson(json);

  @override
  final String id;
  @override
  final String planId;
  @override
  final String title;
  @override
  @JsonKey()
  final String description;
  @override
  @JsonKey()
  final EarsPattern earsPattern;
  final List<String> _acceptanceCriteria;
  @override
  @JsonKey()
  List<String> get acceptanceCriteria {
    if (_acceptanceCriteria is EqualUnmodifiableListView)
      return _acceptanceCriteria;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_acceptanceCriteria);
  }

  @override
  @JsonKey()
  final int sortOrder;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Requirement(id: $id, planId: $planId, title: $title, description: $description, earsPattern: $earsPattern, acceptanceCriteria: $acceptanceCriteria, sortOrder: $sortOrder, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RequirementImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.earsPattern, earsPattern) ||
                other.earsPattern == earsPattern) &&
            const DeepCollectionEquality()
                .equals(other._acceptanceCriteria, _acceptanceCriteria) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      planId,
      title,
      description,
      earsPattern,
      const DeepCollectionEquality().hash(_acceptanceCriteria),
      sortOrder,
      createdAt);

  /// Create a copy of Requirement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RequirementImplCopyWith<_$RequirementImpl> get copyWith =>
      __$$RequirementImplCopyWithImpl<_$RequirementImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RequirementImplToJson(
      this,
    );
  }
}

abstract class _Requirement extends Requirement {
  const factory _Requirement(
      {required final String id,
      required final String planId,
      required final String title,
      final String description,
      final EarsPattern earsPattern,
      final List<String> acceptanceCriteria,
      final int sortOrder,
      required final DateTime createdAt}) = _$RequirementImpl;
  const _Requirement._() : super._();

  factory _Requirement.fromJson(Map<String, dynamic> json) =
      _$RequirementImpl.fromJson;

  @override
  String get id;
  @override
  String get planId;
  @override
  String get title;
  @override
  String get description;
  @override
  EarsPattern get earsPattern;
  @override
  List<String> get acceptanceCriteria;
  @override
  int get sortOrder;
  @override
  DateTime get createdAt;

  /// Create a copy of Requirement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RequirementImplCopyWith<_$RequirementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
