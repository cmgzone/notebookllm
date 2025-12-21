// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mind_map_node.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MindMapNode _$MindMapNodeFromJson(Map<String, dynamic> json) {
  return _MindMapNode.fromJson(json);
}

/// @nodoc
mixin _$MindMapNode {
  String get id => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  List<MindMapNode> get children => throw _privateConstructorUsedError;
  int get level =>
      throw _privateConstructorUsedError; // Hierarchy depth (0 = root)
  int? get colorValue =>
      throw _privateConstructorUsedError; // Custom color as int
  double? get x => throw _privateConstructorUsedError; // Position for layout
  double? get y => throw _privateConstructorUsedError;

  /// Serializes this MindMapNode to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MindMapNode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MindMapNodeCopyWith<MindMapNode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MindMapNodeCopyWith<$Res> {
  factory $MindMapNodeCopyWith(
          MindMapNode value, $Res Function(MindMapNode) then) =
      _$MindMapNodeCopyWithImpl<$Res, MindMapNode>;
  @useResult
  $Res call(
      {String id,
      String label,
      List<MindMapNode> children,
      int level,
      int? colorValue,
      double? x,
      double? y});
}

/// @nodoc
class _$MindMapNodeCopyWithImpl<$Res, $Val extends MindMapNode>
    implements $MindMapNodeCopyWith<$Res> {
  _$MindMapNodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MindMapNode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? children = null,
    Object? level = null,
    Object? colorValue = freezed,
    Object? x = freezed,
    Object? y = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      children: null == children
          ? _value.children
          : children // ignore: cast_nullable_to_non_nullable
              as List<MindMapNode>,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      colorValue: freezed == colorValue
          ? _value.colorValue
          : colorValue // ignore: cast_nullable_to_non_nullable
              as int?,
      x: freezed == x
          ? _value.x
          : x // ignore: cast_nullable_to_non_nullable
              as double?,
      y: freezed == y
          ? _value.y
          : y // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MindMapNodeImplCopyWith<$Res>
    implements $MindMapNodeCopyWith<$Res> {
  factory _$$MindMapNodeImplCopyWith(
          _$MindMapNodeImpl value, $Res Function(_$MindMapNodeImpl) then) =
      __$$MindMapNodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String label,
      List<MindMapNode> children,
      int level,
      int? colorValue,
      double? x,
      double? y});
}

/// @nodoc
class __$$MindMapNodeImplCopyWithImpl<$Res>
    extends _$MindMapNodeCopyWithImpl<$Res, _$MindMapNodeImpl>
    implements _$$MindMapNodeImplCopyWith<$Res> {
  __$$MindMapNodeImplCopyWithImpl(
      _$MindMapNodeImpl _value, $Res Function(_$MindMapNodeImpl) _then)
      : super(_value, _then);

  /// Create a copy of MindMapNode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? children = null,
    Object? level = null,
    Object? colorValue = freezed,
    Object? x = freezed,
    Object? y = freezed,
  }) {
    return _then(_$MindMapNodeImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      children: null == children
          ? _value._children
          : children // ignore: cast_nullable_to_non_nullable
              as List<MindMapNode>,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      colorValue: freezed == colorValue
          ? _value.colorValue
          : colorValue // ignore: cast_nullable_to_non_nullable
              as int?,
      x: freezed == x
          ? _value.x
          : x // ignore: cast_nullable_to_non_nullable
              as double?,
      y: freezed == y
          ? _value.y
          : y // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MindMapNodeImpl extends _MindMapNode {
  const _$MindMapNodeImpl(
      {required this.id,
      required this.label,
      final List<MindMapNode> children = const [],
      this.level = 0,
      this.colorValue,
      this.x,
      this.y})
      : _children = children,
        super._();

  factory _$MindMapNodeImpl.fromJson(Map<String, dynamic> json) =>
      _$$MindMapNodeImplFromJson(json);

  @override
  final String id;
  @override
  final String label;
  final List<MindMapNode> _children;
  @override
  @JsonKey()
  List<MindMapNode> get children {
    if (_children is EqualUnmodifiableListView) return _children;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_children);
  }

  @override
  @JsonKey()
  final int level;
// Hierarchy depth (0 = root)
  @override
  final int? colorValue;
// Custom color as int
  @override
  final double? x;
// Position for layout
  @override
  final double? y;

  @override
  String toString() {
    return 'MindMapNode(id: $id, label: $label, children: $children, level: $level, colorValue: $colorValue, x: $x, y: $y)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MindMapNodeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            const DeepCollectionEquality().equals(other._children, _children) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.colorValue, colorValue) ||
                other.colorValue == colorValue) &&
            (identical(other.x, x) || other.x == x) &&
            (identical(other.y, y) || other.y == y));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, label,
      const DeepCollectionEquality().hash(_children), level, colorValue, x, y);

  /// Create a copy of MindMapNode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MindMapNodeImplCopyWith<_$MindMapNodeImpl> get copyWith =>
      __$$MindMapNodeImplCopyWithImpl<_$MindMapNodeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MindMapNodeImplToJson(
      this,
    );
  }
}

abstract class _MindMapNode extends MindMapNode {
  const factory _MindMapNode(
      {required final String id,
      required final String label,
      final List<MindMapNode> children,
      final int level,
      final int? colorValue,
      final double? x,
      final double? y}) = _$MindMapNodeImpl;
  const _MindMapNode._() : super._();

  factory _MindMapNode.fromJson(Map<String, dynamic> json) =
      _$MindMapNodeImpl.fromJson;

  @override
  String get id;
  @override
  String get label;
  @override
  List<MindMapNode> get children;
  @override
  int get level; // Hierarchy depth (0 = root)
  @override
  int? get colorValue; // Custom color as int
  @override
  double? get x; // Position for layout
  @override
  double? get y;

  /// Create a copy of MindMapNode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MindMapNodeImplCopyWith<_$MindMapNodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MindMap _$MindMapFromJson(Map<String, dynamic> json) {
  return _MindMap.fromJson(json);
}

/// @nodoc
mixin _$MindMap {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get notebookId => throw _privateConstructorUsedError;
  String? get sourceId => throw _privateConstructorUsedError;
  MindMapNode get rootNode => throw _privateConstructorUsedError;
  String? get textContent =>
      throw _privateConstructorUsedError; // Original markdown text version
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this MindMap to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MindMap
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MindMapCopyWith<MindMap> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MindMapCopyWith<$Res> {
  factory $MindMapCopyWith(MindMap value, $Res Function(MindMap) then) =
      _$MindMapCopyWithImpl<$Res, MindMap>;
  @useResult
  $Res call(
      {String id,
      String title,
      String notebookId,
      String? sourceId,
      MindMapNode rootNode,
      String? textContent,
      DateTime createdAt,
      DateTime updatedAt});

  $MindMapNodeCopyWith<$Res> get rootNode;
}

/// @nodoc
class _$MindMapCopyWithImpl<$Res, $Val extends MindMap>
    implements $MindMapCopyWith<$Res> {
  _$MindMapCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MindMap
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? notebookId = null,
    Object? sourceId = freezed,
    Object? rootNode = null,
    Object? textContent = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
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
      notebookId: null == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String,
      sourceId: freezed == sourceId
          ? _value.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String?,
      rootNode: null == rootNode
          ? _value.rootNode
          : rootNode // ignore: cast_nullable_to_non_nullable
              as MindMapNode,
      textContent: freezed == textContent
          ? _value.textContent
          : textContent // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  /// Create a copy of MindMap
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MindMapNodeCopyWith<$Res> get rootNode {
    return $MindMapNodeCopyWith<$Res>(_value.rootNode, (value) {
      return _then(_value.copyWith(rootNode: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MindMapImplCopyWith<$Res> implements $MindMapCopyWith<$Res> {
  factory _$$MindMapImplCopyWith(
          _$MindMapImpl value, $Res Function(_$MindMapImpl) then) =
      __$$MindMapImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String notebookId,
      String? sourceId,
      MindMapNode rootNode,
      String? textContent,
      DateTime createdAt,
      DateTime updatedAt});

  @override
  $MindMapNodeCopyWith<$Res> get rootNode;
}

/// @nodoc
class __$$MindMapImplCopyWithImpl<$Res>
    extends _$MindMapCopyWithImpl<$Res, _$MindMapImpl>
    implements _$$MindMapImplCopyWith<$Res> {
  __$$MindMapImplCopyWithImpl(
      _$MindMapImpl _value, $Res Function(_$MindMapImpl) _then)
      : super(_value, _then);

  /// Create a copy of MindMap
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? notebookId = null,
    Object? sourceId = freezed,
    Object? rootNode = null,
    Object? textContent = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$MindMapImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      notebookId: null == notebookId
          ? _value.notebookId
          : notebookId // ignore: cast_nullable_to_non_nullable
              as String,
      sourceId: freezed == sourceId
          ? _value.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String?,
      rootNode: null == rootNode
          ? _value.rootNode
          : rootNode // ignore: cast_nullable_to_non_nullable
              as MindMapNode,
      textContent: freezed == textContent
          ? _value.textContent
          : textContent // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MindMapImpl extends _MindMap {
  const _$MindMapImpl(
      {required this.id,
      required this.title,
      required this.notebookId,
      this.sourceId,
      required this.rootNode,
      this.textContent,
      required this.createdAt,
      required this.updatedAt})
      : super._();

  factory _$MindMapImpl.fromJson(Map<String, dynamic> json) =>
      _$$MindMapImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String notebookId;
  @override
  final String? sourceId;
  @override
  final MindMapNode rootNode;
  @override
  final String? textContent;
// Original markdown text version
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'MindMap(id: $id, title: $title, notebookId: $notebookId, sourceId: $sourceId, rootNode: $rootNode, textContent: $textContent, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MindMapImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.notebookId, notebookId) ||
                other.notebookId == notebookId) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.rootNode, rootNode) ||
                other.rootNode == rootNode) &&
            (identical(other.textContent, textContent) ||
                other.textContent == textContent) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, notebookId, sourceId,
      rootNode, textContent, createdAt, updatedAt);

  /// Create a copy of MindMap
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MindMapImplCopyWith<_$MindMapImpl> get copyWith =>
      __$$MindMapImplCopyWithImpl<_$MindMapImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MindMapImplToJson(
      this,
    );
  }
}

abstract class _MindMap extends MindMap {
  const factory _MindMap(
      {required final String id,
      required final String title,
      required final String notebookId,
      final String? sourceId,
      required final MindMapNode rootNode,
      final String? textContent,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$MindMapImpl;
  const _MindMap._() : super._();

  factory _MindMap.fromJson(Map<String, dynamic> json) = _$MindMapImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get notebookId;
  @override
  String? get sourceId;
  @override
  MindMapNode get rootNode;
  @override
  String? get textContent; // Original markdown text version
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of MindMap
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MindMapImplCopyWith<_$MindMapImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
