import 'package:freezed_annotation/freezed_annotation.dart';

part 'mind_map_node.freezed.dart';
part 'mind_map_node.g.dart';

/// Represents a node in a mind map graph
@freezed
class MindMapNode with _$MindMapNode {
  const factory MindMapNode({
    required String id,
    required String label,
    @Default([]) List<MindMapNode> children,
    @Default(0) int level, // Hierarchy depth (0 = root)
    int? colorValue, // Custom color as int
    double? x, // Position for layout
    double? y,
  }) = _MindMapNode;

  const MindMapNode._();

  factory MindMapNode.fromBackendJson(Map<String, dynamic> json) => MindMapNode(
        id: json['id'],
        label: json['label'],
        children: (json['children'] as List? ?? [])
            .map((c) => MindMapNode.fromBackendJson(c))
            .toList(),
        level: json['level'] ?? 0,
        colorValue: json['colorValue'],
        x: (json['x'] as num?)?.toDouble(),
        y: (json['y'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'label': label,
        'children': children.map((c) => c.toBackendJson()).toList(),
        'level': level,
        'colorValue': colorValue,
        'x': x,
        'y': y,
      };

  factory MindMapNode.fromJson(Map<String, dynamic> json) =>
      _$MindMapNodeFromJson(json);
}

/// Represents a complete mind map with metadata
@freezed
class MindMap with _$MindMap {
  const factory MindMap({
    required String id,
    required String title,
    required String notebookId,
    String? sourceId,
    required MindMapNode rootNode,
    String? textContent, // Original markdown text version
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _MindMap;

  const MindMap._();

  factory MindMap.fromBackendJson(Map<String, dynamic> json) => MindMap(
        id: json['id'],
        title: json['title'],
        notebookId: json['notebook_id'],
        sourceId: json['source_id'],
        rootNode: MindMapNode.fromBackendJson(json['root_node'] ?? {}),
        textContent: json['text_content'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'title': title,
        'notebook_id': notebookId,
        'source_id': sourceId,
        'root_node': rootNode.toBackendJson(),
        'text_content': textContent,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MindMap.fromJson(Map<String, dynamic> json) =>
      _$MindMapFromJson(json);
}
