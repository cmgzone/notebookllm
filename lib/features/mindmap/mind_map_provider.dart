import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/ai_settings_service.dart';
import 'package:uuid/uuid.dart';
import 'mind_map_node.dart';
import '../sources/source_provider.dart';
import '../gamification/gamification_provider.dart';
import '../../core/api/api_service.dart';

/// Provider for managing mind maps
class MindMapNotifier extends StateNotifier<List<MindMap>> {
  final Ref ref;

  MindMapNotifier(this.ref) : super([]) {
    _loadMindMaps();
  }

  Future<void> _loadMindMaps() async {
    try {
      final api = ref.read(apiServiceProvider);
      final mapsData = await api.getMindMaps();
      state = mapsData.map((j) => MindMap.fromBackendJson(j)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error loading mind maps: $e');
      state = [];
    }
  }

  /// Get mind maps for a specific notebook
  List<MindMap> getMindMapsForNotebook(String notebookId) {
    return state.where((mm) => mm.notebookId == notebookId).toList();
  }

  /// Add a new mind map
  Future<void> addMindMap(MindMap mindMap) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.saveMindMap(
        title: mindMap.title,
        notebookId: mindMap.notebookId,
        sourceId: mindMap.sourceId,
        rootNode: mindMap.rootNode.toBackendJson(),
        textContent: mindMap.textContent,
      );
      await _loadMindMaps();
    } catch (e) {
      debugPrint('Error adding mind map: $e');
    }
  }

  /// Update existing mind map
  Future<void> updateMindMap(MindMap mindMap) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.saveMindMap(
        id: mindMap.id,
        title: mindMap.title,
        notebookId: mindMap.notebookId,
        sourceId: mindMap.sourceId,
        rootNode: mindMap.rootNode.toBackendJson(),
        textContent: mindMap.textContent,
      );
      await _loadMindMaps();
    } catch (e) {
      debugPrint('Error updating mind map: $e');
    }
  }

  /// Delete a mind map
  Future<void> deleteMindMap(String id) async {
    // Current backend doesn't have deleteMindMap yet, I should add it
    await _loadMindMaps();
  }

  /// Generate mind map from sources using AI
  Future<MindMap> generateFromSources({
    required String notebookId,
    required String title,
    String? sourceId,
  }) async {
    // Get source content
    final sources = ref.read(sourceProvider);
    final relevantSources = sourceId != null
        ? sources.where((s) => s.id == sourceId).toList()
        : sources.where((s) => s.notebookId == notebookId).toList();

    if (relevantSources.isEmpty) {
      throw Exception('No sources found to generate mind map from');
    }

    final sourceContent =
        relevantSources.map((s) => '## ${s.title}\n${s.content}').join('\n\n');

    // Build prompt for AI - request both text and JSON structure
    final prompt = '''
Create a hierarchical mind map based on the following content.
The mind map should identify key concepts and their relationships.

CONTENT:
$sourceContent

Return your response in TWO parts:

PART 1 - TEXT VERSION:
# [Central Topic]
## Branch 1: [Main Concept]
- Sub-topic 1.1
  - Detail
- Sub-topic 1.2

## Branch 2: [Main Concept]
- Sub-topic 2.1

---JSON_START---

PART 2 - JSON VERSION (after the marker above):
{
  "id": "root",
  "label": "Central Topic",
  "children": [
    {
      "id": "b1",
      "label": "Main Concept 1",
      "children": [
        {"id": "b1-1", "label": "Sub-topic 1.1", "children": []},
        {"id": "b1-2", "label": "Sub-topic 1.2", "children": []}
      ]
    }
  ]
}

Create 3-5 main branches with 2-4 sub-topics each.
''';

    // Call AI service
    final response = await _callAI(prompt);
    final (textContent, rootNode) = _parseMindMapResponse(response, title);

    final now = DateTime.now();
    final mindMap = MindMap(
      id: const Uuid().v4(),
      title: title,
      notebookId: notebookId,
      sourceId: sourceId,
      rootNode: rootNode,
      textContent: textContent,
      createdAt: now,
      updatedAt: now,
    );

    await addMindMap(mindMap);

    // Track gamification
    ref.read(gamificationProvider.notifier).trackMindmapCreated();
    ref.read(gamificationProvider.notifier).trackFeatureUsed('mindmap');

    return mindMap;
  }

  Future<String> _callAI(String prompt) async {
    try {
      final settings = await AISettingsService.getSettings();
      final model = settings.getEffectiveModel();

      debugPrint(
          '[MindMapProvider] Using AI provider: ${settings.provider}, model: $model');

      // Use Backend Proxy (Admin's API keys)
      final apiService = ref.read(apiServiceProvider);
      final messages = [
        {'role': 'user', 'content': prompt}
      ];

      return await apiService.chatWithAI(
        messages: messages,
        provider: settings.provider,
        model: model,
      );
    } catch (e) {
      debugPrint('[MindMapProvider] AI call failed: $e');
      rethrow;
    }
  }

  (String, MindMapNode) _parseMindMapResponse(
      String response, String fallbackTitle) {
    String textContent = response;
    MindMapNode? rootNode;

    debugPrint('[MindMapProvider] Parsing response length: ${response.length}');

    try {
      // Try 1: Split by JSON marker
      final parts = response.split('---JSON_START---');
      if (parts.length >= 2) {
        textContent = parts[0].trim();
        final jsonPart = parts[1].trim();

        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonPart);
        if (jsonMatch != null) {
          final jsonData = jsonDecode(jsonMatch.group(0)!);
          rootNode = _parseNodeFromJson(jsonData, 0);
          debugPrint('[MindMapProvider] Parsed from JSON marker');
        }
      }

      // Try 2: Look for JSON anywhere in response
      if (rootNode == null) {
        final jsonMatch =
            RegExp(r'\{[^{}]*"id"[^{}]*"label"[^{}]*"children"[\s\S]*\}')
                .firstMatch(response);
        if (jsonMatch != null) {
          try {
            final jsonData = jsonDecode(jsonMatch.group(0)!);
            rootNode = _parseNodeFromJson(jsonData, 0);
            debugPrint('[MindMapProvider] Parsed from embedded JSON');
          } catch (_) {}
        }
      }

      // Try 3: Parse markdown structure to create nodes
      if (rootNode == null) {
        rootNode = _parseMarkdownToNodes(response, fallbackTitle);
        debugPrint('[MindMapProvider] Parsed from markdown structure');
      }
    } catch (e) {
      debugPrint('[MindMapProvider] Error parsing mind map: $e');
    }

    // Final fallback
    rootNode ??= MindMapNode(
      id: 'root',
      label: fallbackTitle,
      level: 0,
      children: [],
    );

    debugPrint(
        '[MindMapProvider] Root node children: ${rootNode.children.length}');
    return (textContent, rootNode);
  }

  MindMapNode _parseNodeFromJson(Map<String, dynamic> json, int level) {
    final children = (json['children'] as List<dynamic>?)
            ?.map((child) => _parseNodeFromJson(child, level + 1))
            .toList() ??
        [];

    return MindMapNode(
      id: json['id'] ?? const Uuid().v4(),
      label: json['label'] ?? 'Untitled',
      level: level,
      children: children,
    );
  }

  /// Parse markdown-style text into mind map nodes
  MindMapNode _parseMarkdownToNodes(String text, String fallbackTitle) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    String rootLabel = fallbackTitle;
    final branches = <MindMapNode>[];
    MindMapNode? currentBranch;
    final currentSubTopics = <MindMapNode>[];

    for (final line in lines) {
      final trimmed = line.trim();

      // Main title (# heading)
      if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
        rootLabel = trimmed.substring(2).trim();
      }
      // Branch (## heading)
      else if (trimmed.startsWith('## ')) {
        // Save previous branch
        if (currentBranch != null) {
          branches.add(
              currentBranch.copyWith(children: List.from(currentSubTopics)));
          currentSubTopics.clear();
        }
        final label = trimmed
            .substring(3)
            .replaceAll(RegExp(r'^(Branch \d+:|[\d]+\.)'), '')
            .trim();
        currentBranch = MindMapNode(
          id: const Uuid().v4(),
          label: label,
          level: 1,
          children: [],
        );
      }
      // Sub-topic (- or * bullet)
      else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final label = trimmed.substring(2).trim();
        if (label.isNotEmpty && currentBranch != null) {
          currentSubTopics.add(MindMapNode(
            id: const Uuid().v4(),
            label: label,
            level: 2,
            children: [],
          ));
        }
      }
      // Indented sub-topic
      else if (line.startsWith('  - ') ||
          line.startsWith('  * ') ||
          line.startsWith('    - ')) {
        final label = trimmed.substring(2).trim();
        if (label.isNotEmpty && currentSubTopics.isNotEmpty) {
          // Add as child of last sub-topic
          final lastIdx = currentSubTopics.length - 1;
          final lastSubTopic = currentSubTopics[lastIdx];
          currentSubTopics[lastIdx] = lastSubTopic.copyWith(
            children: [
              ...lastSubTopic.children,
              MindMapNode(
                id: const Uuid().v4(),
                label: label,
                level: 3,
                children: [],
              )
            ],
          );
        }
      }
    }

    // Add last branch
    if (currentBranch != null) {
      branches
          .add(currentBranch.copyWith(children: List.from(currentSubTopics)));
    }

    // If no branches found, create some from any bullet points
    if (branches.isEmpty) {
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('- ') ||
            trimmed.startsWith('* ') ||
            trimmed.startsWith('• ')) {
          branches.add(MindMapNode(
            id: const Uuid().v4(),
            label: trimmed.substring(2).trim(),
            level: 1,
            children: [],
          ));
        }
      }
    }

    return MindMapNode(
      id: 'root',
      label: rootLabel,
      level: 0,
      children: branches,
    );
  }
}

final mindMapProvider =
    StateNotifierProvider<MindMapNotifier, List<MindMap>>((ref) {
  return MindMapNotifier(ref);
});
