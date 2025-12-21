import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'mind_map_node.dart';
import 'mind_map_provider.dart';

/// Screen for viewing a mind map with visual graph
class MindMapScreen extends ConsumerStatefulWidget {
  final String mindMapId;

  const MindMapScreen({super.key, required this.mindMapId});

  @override
  ConsumerState<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends ConsumerState<MindMapScreen> {
  bool _showTextMode = false;
  final TransformationController _transformController =
      TransformationController();
  String? _selectedNodeId;

  // Cache node positions to avoid recalculating every frame
  final Map<String, Offset> _nodePositions = {};

  @override
  void initState() {
    super.initState();
    // Center the view on the mind map after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerView();
    });
  }

  void _centerView() {
    // Center on the root node (1000, 1000) with some zoom out
    final viewportSize = MediaQuery.of(context).size;
    const scale = 0.5; // Start zoomed out to see more
    final translateX = (viewportSize.width / 2) - (1000 * scale);
    final translateY = (viewportSize.height / 2) - (1000 * scale);

    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, scale);
    matrix.setEntry(1, 1, scale);
    matrix.setEntry(2, 2, 1.0);
    matrix.setTranslationRaw(translateX, translateY, 0);
    _transformController.value = matrix;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-calculate layout if needed when dependencies change
  }

  void _calculateLayout(MindMapNode root) {
    _nodePositions.clear();
    // Start at center
    _layoutRecursive(root, 1000, 1000, 0, 0);
  }

  void _layoutRecursive(
      MindMapNode node, double x, double y, double parentAngle, int depth) {
    _nodePositions[node.id] = Offset(x, y);

    final children = node.children;
    if (children.isEmpty) return;

    final count = children.length;
    // Dynamic radius: larger for root to give space, smaller for leaves
    final double radius = depth == 0 ? 200.0 : 160.0;

    if (depth == 0) {
      // Root: Distribute children in a full circle
      final step = (2 * math.pi) / count;
      for (int i = 0; i < count; i++) {
        // Start from -PI/2 (up) to look nice
        final angle = (i * step) - (math.pi / 2);
        final cx = x + radius * math.cos(angle);
        final cy = y + radius * math.sin(angle);
        _layoutRecursive(children[i], cx, cy, angle, depth + 1);
      }
    } else {
      // Branch: Distribute within a wedge pointing AWAY from parent
      // The 'parentAngle' is the direction FROM parent TO this node.
      // We want to center the children around this same angle.

      // Wedge size depends on number of children
      // ~60 degrees for 1-2 items, up to ~120 degrees for many
      final double wedgeSize =
          math.min(math.pi * 0.8, math.max(math.pi / 3, count * (math.pi / 8)));

      final startAngle = parentAngle - (wedgeSize / 2);
      final step = count > 1 ? wedgeSize / (count - 1) : 0;

      for (int i = 0; i < count; i++) {
        final angle = count == 1 ? parentAngle : startAngle + (step * i);
        final cx = x + radius * math.cos(angle);
        final cy = y + radius * math.sin(angle);
        _layoutRecursive(children[i], cx, cy, angle, depth + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mindMaps = ref.watch(mindMapProvider);
    final mindMap = mindMaps.firstWhere(
      (mm) => mm.id == widget.mindMapId,
      orElse: () => MindMap(
        id: '',
        title: 'Not Found',
        notebookId: '',
        rootNode: const MindMapNode(id: 'root', label: 'Empty'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Calculate layout once for this build
    if (mindMap.rootNode.label != 'Empty') {
      _calculateLayout(mindMap.rootNode);
    }

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(mindMap.title),
        actions: [
          IconButton(
            icon: Icon(_showTextMode ? LucideIcons.network : LucideIcons.text),
            onPressed: () => setState(() => _showTextMode = !_showTextMode),
            tooltip: _showTextMode ? 'Visual Mode' : 'Text Mode',
          ),
          IconButton(
            icon: const Icon(LucideIcons.zoomIn),
            onPressed: _zoomIn,
          ),
          IconButton(
            icon: const Icon(LucideIcons.zoomOut),
            onPressed: _zoomOut,
          ),
          IconButton(
            icon: const Icon(LucideIcons.maximize2),
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: _showTextMode
          ? _buildTextView(mindMap, scheme, text)
          : _buildGraphView(mindMap, scheme, text),
    );
  }

  Widget _buildTextView(MindMap mindMap, ColorScheme scheme, TextTheme text) {
    if (mindMap.textContent == null || mindMap.textContent!.isEmpty) {
      return Center(
        child: Text(
          'No text content available',
          style: text.bodyLarge?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        mindMap.textContent!,
        style: text.bodyLarge?.copyWith(
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildGraphView(MindMap mindMap, ColorScheme scheme, TextTheme text) {
    // Check if mind map is empty or not found
    if (mindMap.id.isEmpty || mindMap.rootNode.label == 'Empty') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.network,
              size: 64,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Mind Map Not Found',
              style: text.titleLarge?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This mind map may have been deleted',
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Check if mind map has no branches (only root node)
    if (mindMap.rootNode.children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.alertCircle,
                size: 64,
                color: scheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Mind Map Structure Issue',
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This mind map only has a root node with no branches.\nTry switching to Text Mode to see the content.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => setState(() => _showTextMode = true),
                icon: const Icon(LucideIcons.text),
                label: const Text('View as Text'),
              ),
              if (mindMap.textContent != null &&
                  mindMap.textContent!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Root: ${mindMap.rootNode.label}',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mindMap.textContent!.length > 200
                              ? '${mindMap.textContent!.substring(0, 200)}...'
                              : mindMap.textContent!,
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      color: scheme.surface,
      child: InteractiveViewer(
        transformationController: _transformController,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 4.0,
        child: SizedBox(
          width: 2000,
          height: 2000,
          child: CustomPaint(
            painter: MindMapPainter(
              rootNode: mindMap.rootNode,
              scheme: scheme,
              selectedNodeId: _selectedNodeId,
              nodePositions: _nodePositions,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Recursively build widgets using cached positions - flattened
                ..._buildFlattenedWidgets(mindMap.rootNode, scheme, text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFlattenedWidgets(
    MindMapNode node,
    ColorScheme scheme,
    TextTheme text,
  ) {
    if (!_nodePositions.containsKey(node.id)) return [];

    // BETTER: Reuse the recursive traversal to build widgets, but use the MAP for coords
    // This ensures we have the 'depth' variable available for styling.
    return _collectWidgetsRecursive(node, 0, scheme, text);
  }

  List<Widget> _collectWidgetsRecursive(
      MindMapNode node, int depth, ColorScheme scheme, TextTheme text) {
    final List<Widget> list = [];
    final pos = _nodePositions[node.id];

    if (pos != null) {
      list.add(
        Positioned(
          left: pos.dx - 75, // Center horizontally (width 150)
          top: pos.dy - 30, // Center vertically roughly
          child: GestureDetector(
            onTap: () => setState(() => _selectedNodeId = node.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              width: 150,
              decoration: BoxDecoration(
                color: _getNodeColor(depth, scheme),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedNodeId == node.id
                      ? scheme.primary
                      : scheme.outline.withValues(alpha: 0.1),
                  width: _selectedNodeId == node.id ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                node.label,
                style: text.bodyMedium?.copyWith(
                  color: _getNodeTextColor(depth, scheme),
                  fontWeight: depth == 0 ? FontWeight.bold : FontWeight.w500,
                  fontSize: depth == 0 ? 16 : 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }

    for (var child in node.children) {
      list.addAll(_collectWidgetsRecursive(child, depth + 1, scheme, text));
    }
    return list;
  }

  Color _getNodeColor(int depth, ColorScheme scheme) {
    if (depth == 0) return scheme.primaryContainer;
    if (depth == 1) return scheme.secondaryContainer;
    return scheme.surfaceContainerHighest;
  }

  Color _getNodeTextColor(int depth, ColorScheme scheme) {
    if (depth == 0) return scheme.onPrimaryContainer;
    if (depth == 1) return scheme.onSecondaryContainer;
    return scheme.onSurface;
  }

  void _zoomIn() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.3).clamp(0.1, 4.0);
    _transformController.value = Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(2, 2, newScale)
      ..setTranslationRaw(
        _transformController.value.getTranslation().x,
        _transformController.value.getTranslation().y,
        0,
      ); // Keep translation? Ideally zoom to center but this is simple
  }

  void _zoomOut() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.3).clamp(0.1, 4.0);
    _transformController.value = Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(2, 2, newScale)
      ..setTranslationRaw(
        _transformController.value.getTranslation().x,
        _transformController.value.getTranslation().y,
        0,
      );
  }

  void _resetZoom() {
    _centerView();
  }
}

/// Custom painter for drawing connection lines between nodes
class MindMapPainter extends CustomPainter {
  final MindMapNode rootNode;
  final ColorScheme scheme;
  final String? selectedNodeId;
  final Map<String, Offset> nodePositions;

  MindMapPainter({
    required this.rootNode,
    required this.scheme,
    this.selectedNodeId,
    required this.nodePositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scheme.outline.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    _drawConnectionsRecursive(canvas, rootNode, paint);
  }

  void _drawConnectionsRecursive(
    Canvas canvas,
    MindMapNode node,
    Paint paint,
  ) {
    final startPos = nodePositions[node.id];
    if (startPos == null) return;

    for (var child in node.children) {
      final endPos = nodePositions[child.id];
      if (endPos != null) {
        final path = Path()
          ..moveTo(startPos.dx, startPos.dy)
          ..quadraticBezierTo(
            (startPos.dx + endPos.dx) / 2,
            (startPos.dy + endPos.dy) / 2, // Straighter curve
            endPos.dx,
            endPos.dy,
          );
        canvas.drawPath(path, paint);
      }
      _drawConnectionsRecursive(canvas, child, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MindMapPainter oldDelegate) {
    return oldDelegate.rootNode != rootNode ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.nodePositions != nodePositions;
  }
}
