import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../core/ai/ai_provider.dart';
import '../../subscription/services/credit_manager.dart';
import '../planning_provider.dart';

/// Device frame definitions for mobile preview
enum DeviceFrame {
  responsive('Responsive', null, null, LucideIcons.monitor),
  iphone14('iPhone 14', 390, 844, LucideIcons.smartphone),
  iphone14Pro('iPhone 14 Pro', 393, 852, LucideIcons.smartphone),
  iphoneSE('iPhone SE', 375, 667, LucideIcons.smartphone),
  pixel7('Pixel 7', 412, 915, LucideIcons.smartphone),
  galaxyS23('Galaxy S23', 360, 780, LucideIcons.smartphone),
  ipadMini('iPad Mini', 744, 1133, LucideIcons.tablet),
  ipadPro('iPad Pro 11"', 834, 1194, LucideIcons.tablet);

  final String name;
  final double? width;
  final double? height;
  final IconData icon;

  const DeviceFrame(this.name, this.width, this.height, this.icon);
}

/// Project Prototype Generator Screen
/// Auto-generates all screens for a project with navigation, interactive WebView preview
class ProjectPrototypeScreen extends ConsumerStatefulWidget {
  final String planId;

  const ProjectPrototypeScreen({super.key, required this.planId});

  @override
  ConsumerState<ProjectPrototypeScreen> createState() =>
      _ProjectPrototypeScreenState();
}

class _ScreenDefinition {
  final String id;
  final String name;
  final String description;
  final bool isGenerated;
  final String? html;

  _ScreenDefinition({
    required this.id,
    required this.name,
    required this.description,
    this.isGenerated = false,
    this.html,
  });

  _ScreenDefinition copyWith({
    String? id,
    String? name,
    String? description,
    bool? isGenerated,
    String? html,
  }) {
    return _ScreenDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isGenerated: isGenerated ?? this.isGenerated,
      html: html ?? this.html,
    );
  }
}

class _ProjectPrototypeScreenState
    extends ConsumerState<ProjectPrototypeScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  WebViewController? _webViewController;
  String? _fullPrototypeHtml;
  Uint8List? _screenshot;
  bool _isGenerating = false;
  bool _isCapturing = false;
  bool _isSaving = false;
  bool _webViewReady = false;
  String _selectedStyle = 'modern';
  String _selectedColorScheme = 'purple';
  String _currentScreen = 'home';
  double _generationProgress = 0;
  String _generationStatus = '';
  DeviceFrame _selectedDevice = DeviceFrame.iphone14;
  bool _isLandscape = false;

  // Screen definitions
  List<_ScreenDefinition> _screens = [];
  bool _screensAnalyzed = false;
  bool _isAnalyzing = false;

  final List<String> _styles = [
    'modern',
    'minimal',
    'glassmorphism',
    'dark',
    'gradient',
    'corporate',
  ];

  final Map<String, List<String>> _colorSchemes = {
    'purple': ['#8B5CF6', '#A78BFA', '#C4B5FD'],
    'blue': ['#3B82F6', '#60A5FA', '#93C5FD'],
    'green': ['#10B981', '#34D399', '#6EE7B7'],
    'orange': ['#F97316', '#FB923C', '#FDBA74'],
    'pink': ['#EC4899', '#F472B6', '#F9A8D4'],
    'teal': ['#14B8A6', '#2DD4BF', '#5EEAD4'],
  };

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _webViewReady = true);
            }
          },
          onNavigationRequest: (request) {
            // Handle internal navigation
            if (request.url.startsWith('app://')) {
              final screenId = request.url.replaceFirst('app://', '');
              setState(() => _currentScreen = screenId);
              _navigateToScreen(screenId);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  void _navigateToScreen(String screenId) {
    if (_fullPrototypeHtml != null) {
      _webViewController?.runJavaScript('navigateTo("$screenId")');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(scheme, text),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProjectInfo(scheme, text),
                  const SizedBox(height: 20),
                  _buildStyleSection(scheme, text),
                  const SizedBox(height: 20),
                  if (!_screensAnalyzed) ...[
                    _buildAnalyzeButton(scheme),
                  ] else ...[
                    _buildScreensList(scheme, text),
                    const SizedBox(height: 20),
                    _buildGenerateButton(scheme),
                  ],
                  if (_isGenerating) ...[
                    const SizedBox(height: 20),
                    _buildProgressSection(scheme, text),
                  ],
                  if (_fullPrototypeHtml != null) ...[
                    const SizedBox(height: 24),
                    _buildPreviewSection(scheme, text),
                    const SizedBox(height: 16),
                    _buildScreenNavigation(scheme, text),
                    const SizedBox(height: 16),
                    _buildActionButtons(scheme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(ColorScheme scheme, TextTheme text) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 140,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          LucideIcons.layoutDashboard,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Project Prototype',
                              style: text.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Auto-generate all screens with navigation',
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildProjectInfo(ColorScheme scheme, TextTheme text) {
    final planState = ref.watch(planningProvider);
    final plan = planState.currentPlan;

    if (plan == null) {
      return Card(
        color: scheme.errorContainer,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No plan loaded'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.folder, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.description,
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  '${plan.requirements.length} Requirements',
                  LucideIcons.fileText,
                  scheme,
                ),
                _buildInfoChip(
                  '${plan.tasks.length} Tasks',
                  LucideIcons.listChecks,
                  scheme,
                ),
                _buildInfoChip(
                  '${plan.designNotes.length} Design Notes',
                  LucideIcons.penTool,
                  scheme,
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildInfoChip(String label, IconData icon, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSection(ColorScheme scheme, TextTheme text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.paintbrush, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Design Style',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Style chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _styles.map((style) {
                final isSelected = style == _selectedStyle;
                return ChoiceChip(
                  label: Text(
                    style[0].toUpperCase() + style.substring(1),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedStyle = style);
                  },
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : scheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Color Scheme',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: _colorSchemes.entries.map((entry) {
                final isSelected = entry.key == _selectedColorScheme;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedColorScheme = entry.key),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: entry.value
                              .map((c) =>
                                  Color(int.parse(c.replaceFirst('#', '0xFF'))))
                              .toList(),
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(int.parse(entry.value[0]
                                          .replaceFirst('#', '0xFF')))
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildAnalyzeButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _isAnalyzing ? null : _analyzeProject,
        icon: _isAnalyzing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : const Icon(LucideIcons.scan),
        label: Text(
            _isAnalyzing ? 'Analyzing Project...' : 'Analyze & Plan Screens'),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale();
  }

  Widget _buildScreensList(ColorScheme scheme, TextTheme text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.layers, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Screens to Generate (${_screens.length})',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _analyzeProject,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Re-analyze'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_screens.length, (index) {
              final screen = _screens[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: screen.isGenerated
                      ? Colors.green.withValues(alpha: 0.1)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: screen.isGenerated
                        ? Colors.green.withValues(alpha: 0.3)
                        : scheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: screen.isGenerated
                            ? Colors.green
                            : scheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: screen.isGenerated
                            ? const Icon(LucideIcons.check,
                                color: Colors.white, size: 16)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            screen.name,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            screen.description,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildGenerateButton(ColorScheme scheme) {
    final allGenerated = _screens.every((s) => s.isGenerated);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _isGenerating ? null : _generateFullPrototype,
        icon: _isGenerating
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Icon(allGenerated ? LucideIcons.refreshCw : LucideIcons.wand2),
        label: Text(_isGenerating
            ? 'Generating...'
            : allGenerated
                ? 'Regenerate All Screens'
                : 'Generate Full Prototype'),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).scale();
  }

  Widget _buildProgressSection(ColorScheme scheme, TextTheme text) {
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _generationStatus,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${(_generationProgress * 100).toInt()}%',
                  style: text.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _generationProgress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildDeviceSelector(ColorScheme scheme, TextTheme text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.smartphone, color: scheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Device Preview',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                // Orientation toggle
                if (_selectedDevice != DeviceFrame.responsive)
                  IconButton(
                    onPressed: () =>
                        setState(() => _isLandscape = !_isLandscape),
                    icon: Icon(
                      _isLandscape
                          ? LucideIcons.smartphone
                          : LucideIcons.tablet,
                      size: 18,
                    ),
                    tooltip: _isLandscape ? 'Portrait' : 'Landscape',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          scheme.primaryContainer.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: DeviceFrame.values.length,
                itemBuilder: (context, index) {
                  final device = DeviceFrame.values[index];
                  final isSelected = device == _selectedDevice;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(device.icon, size: 14),
                      label: Text(device.name,
                          style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedDevice = device),
                      selectedColor: scheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : scheme.onSurface,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(ColorScheme scheme, TextTheme text) {
    // Calculate device dimensions
    double? deviceWidth = _selectedDevice.width;
    double? deviceHeight = _selectedDevice.height;

    if (_isLandscape && deviceWidth != null && deviceHeight != null) {
      final temp = deviceWidth;
      deviceWidth = deviceHeight;
      deviceHeight = temp;
    }

    // Scale to fit screen
    final screenWidth = MediaQuery.of(context).size.width - 32;
    double scale = 1.0;
    double previewWidth = screenWidth;
    double previewHeight = 600;

    if (deviceWidth != null && deviceHeight != null) {
      // Calculate scale to fit
      final widthScale =
          (screenWidth - 40) / deviceWidth; // 40 for device frame padding
      final heightScale = 600 / deviceHeight;
      scale = widthScale < heightScale ? widthScale : heightScale;
      if (scale > 1) scale = 1; // Don't scale up

      previewWidth = deviceWidth * scale + 40;
      previewHeight =
          deviceHeight * scale + 80; // Extra for notch/home indicator
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.monitor, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Interactive Prototype',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _webViewReady
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _webViewReady ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _webViewReady ? 'Live' : 'Loading...',
                    style: TextStyle(
                      color: _webViewReady
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Device selector
        _buildDeviceSelector(scheme, text),
        const SizedBox(height: 12),
        // Device frame preview
        Center(
          child: Screenshot(
            controller: _screenshotController,
            child: _selectedDevice == DeviceFrame.responsive
                ? Container(
                    height: 600,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildWebView(),
                  )
                : _buildDeviceFrame(scheme, previewWidth, previewHeight,
                    deviceWidth, deviceHeight, scale),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildDeviceFrame(
      ColorScheme scheme,
      double frameWidth,
      double frameHeight,
      double? deviceWidth,
      double? deviceHeight,
      double scale) {
    final isPhone = _selectedDevice.name.contains('iPhone') ||
        _selectedDevice.name.contains('Pixel') ||
        _selectedDevice.name.contains('Galaxy');

    return Container(
      width: frameWidth,
      height: frameHeight,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(isPhone ? 40 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      padding: EdgeInsets.all(isPhone ? 12 : 8),
      child: Column(
        children: [
          // Notch/Dynamic Island for phones
          if (isPhone) ...[
            Container(
              width: 120,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Screen
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isPhone ? 28 : 12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildWebView(),
            ),
          ),
          // Home indicator for phones
          if (isPhone) ...[
            const SizedBox(height: 8),
            Container(
              width: 134,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildWebView() {
    if (_webViewController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (!_webViewReady)
          Container(
            color: Colors.white,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading preview...'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScreenNavigation(ColorScheme scheme, TextTheme text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Navigate Screens',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _screens.length,
                itemBuilder: (context, index) {
                  final screen = _screens[index];
                  final isActive = screen.id == _currentScreen;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(screen.name),
                      selected: isActive,
                      onSelected: (_) {
                        setState(() => _currentScreen = screen.id);
                        _navigateToScreen(screen.id);
                      },
                      selectedColor: scheme.primary,
                      labelStyle: TextStyle(
                        color: isActive ? Colors.white : scheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isCapturing ? null : _captureScreenshot,
            icon: _isCapturing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.camera),
            label: const Text('Screenshot'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportHtml,
            icon: const Icon(LucideIcons.download),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveAsDesignNote,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.save),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  /// Analyze project requirements and determine screens to generate
  Future<void> _analyzeProject() async {
    final planState = ref.read(planningProvider);
    final plan = planState.currentPlan;

    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No plan loaded')),
      );
      return;
    }

    // Check credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.chatMessage * 2,
      feature: 'project_prototype_analyze',
    );
    if (!hasCredits) return;

    setState(() {
      _isAnalyzing = true;
      _screens = [];
    });

    try {
      final prompt =
          '''Analyze this project and identify all the screens/pages needed for a complete application prototype.

**Project:** ${plan.title}
**Description:** ${plan.description}

**Requirements:**
${plan.requirements.map((r) => '- ${r.title}: ${r.description}').join('\n')}

**Tasks:**
${plan.tasks.map((t) => '- ${t.title}').join('\n')}

**Design Notes:**
${plan.designNotes.map((d) => '- ${d.content.length > 100 ? d.content.substring(0, 100) : d.content}...').join('\n')}

Based on this project, list ALL screens needed for a complete prototype. For each screen provide:
1. A unique ID (lowercase, no spaces, e.g., "home", "login", "dashboard")
2. Screen name (human readable)
3. Brief description of what the screen contains

Format your response EXACTLY like this (one screen per line):
SCREEN|id|Name|Description

Example:
SCREEN|home|Home|Landing page with hero section and feature highlights
SCREEN|login|Login|User authentication with email and password
SCREEN|dashboard|Dashboard|Main user dashboard with stats and recent activity

List 5-10 screens that would make a complete prototype.''';

      final aiNotifier = ref.read(aiProvider.notifier);
      await aiNotifier.generateContent(prompt, style: ChatStyle.standard);

      final aiState = ref.read(aiProvider);
      if (aiState.error != null) {
        throw Exception(aiState.error);
      }

      final response = aiState.lastResponse ?? '';
      final parsedScreens = _parseScreensFromResponse(response);

      if (parsedScreens.isEmpty) {
        // Fallback to default screens
        parsedScreens.addAll([
          _ScreenDefinition(
            id: 'home',
            name: 'Home',
            description: 'Landing page with hero section',
          ),
          _ScreenDefinition(
            id: 'login',
            name: 'Login',
            description: 'User authentication screen',
          ),
          _ScreenDefinition(
            id: 'dashboard',
            name: 'Dashboard',
            description: 'Main user dashboard',
          ),
          _ScreenDefinition(
            id: 'settings',
            name: 'Settings',
            description: 'User settings and preferences',
          ),
        ]);
      }

      setState(() {
        _screens = parsedScreens;
        _screensAnalyzed = true;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isAnalyzing = false);
      }
    }
  }

  List<_ScreenDefinition> _parseScreensFromResponse(String response) {
    final screens = <_ScreenDefinition>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().startsWith('SCREEN|')) {
        final parts = line.trim().split('|');
        if (parts.length >= 4) {
          screens.add(_ScreenDefinition(
            id: parts[1].trim(),
            name: parts[2].trim(),
            description: parts[3].trim(),
          ));
        }
      }
    }

    return screens;
  }

  /// Generate the full prototype with all screens
  Future<void> _generateFullPrototype() async {
    if (_screens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please analyze the project first')),
      );
      return;
    }

    // Check credits (more credits for full prototype)
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.chatMessage * (_screens.length + 2),
      feature: 'project_prototype_generate',
    );
    if (!hasCredits) return;

    setState(() {
      _isGenerating = true;
      _generationProgress = 0;
      _generationStatus = 'Preparing prototype generation...';
      // Reset all screens to not generated
      _screens = _screens.map((s) => s.copyWith(isGenerated: false)).toList();
    });

    try {
      final planState = ref.read(planningProvider);
      final plan = planState.currentPlan;
      final colors = _colorSchemes[_selectedColorScheme]!;

      // Build the full prototype prompt
      final prompt = _buildFullPrototypePrompt(plan, colors);

      setState(() {
        _generationProgress = 0.1;
        _generationStatus = 'Generating all screens...';
      });

      final aiNotifier = ref.read(aiProvider.notifier);
      await aiNotifier.generateContent(prompt, style: ChatStyle.standard);

      final aiState = ref.read(aiProvider);
      if (aiState.error != null) {
        throw Exception(aiState.error);
      }

      setState(() {
        _generationProgress = 0.8;
        _generationStatus = 'Processing HTML...';
      });

      final response = aiState.lastResponse ?? '';
      final html = _extractHtmlFromResponse(response);

      if (html.isNotEmpty) {
        setState(() {
          _fullPrototypeHtml = html;
          _generationProgress = 0.9;
          _generationStatus = 'Loading preview...';
          // Mark all screens as generated
          _screens =
              _screens.map((s) => s.copyWith(isGenerated: true)).toList();
          _currentScreen = _screens.first.id;
        });

        await _webViewController?.loadHtmlString(html);

        setState(() {
          _generationProgress = 1.0;
          _generationStatus = 'Complete!';
        });

        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        throw Exception('Could not generate valid HTML');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  String _buildFullPrototypePrompt(dynamic plan, List<String> colors) {
    final screensList = _screens
        .map((s) => '- ${s.name} (id: ${s.id}): ${s.description}')
        .join('\n');

    // Get device info for mobile-first design
    final deviceInfo = _selectedDevice != DeviceFrame.responsive
        ? 'Target Device: ${_selectedDevice.name} (${_selectedDevice.width?.toInt()}x${_selectedDevice.height?.toInt()}px)'
        : 'Target: Responsive (mobile-first)';

    return '''Generate a COMPLETE, INTERACTIVE MOBILE APP prototype with ALL screens and working navigation.

**Project:** ${plan?.title ?? 'Project'}
**Description:** ${plan?.description ?? ''}
**$deviceInfo**

**Screens to Generate:**
$screensList

**Style:** $_selectedStyle
**Primary Color:** ${colors[0]}
**Secondary Color:** ${colors[1]}
**Accent Color:** ${colors[2]}

**CRITICAL REQUIREMENTS - MOBILE APP DESIGN:**

1. **Mobile-First Design**: 
   - Design for mobile screens (390px width typical)
   - Use mobile app patterns (bottom nav, floating buttons, swipe gestures)
   - Touch-friendly tap targets (min 44px)
   - No horizontal scrolling

2. **Single HTML File**: Create ONE self-contained HTML file with ALL screens

3. **Mobile Navigation System**:
   - Bottom navigation bar (fixed at bottom) for main screens
   - Back buttons in headers for sub-screens
   - Implement `navigateTo(screenId)` function
   - Smooth transitions between screens

4. **Screen Structure**:
```html
<div id="home" class="screen active">
  <header class="app-header">...</header>
  <main class="screen-content">...</main>
</div>
```

5. **Navigation JavaScript**:
```javascript
function navigateTo(screenId) {
  document.querySelectorAll('.screen').forEach(s => {
    s.classList.remove('active');
    s.style.display = 'none';
  });
  const target = document.getElementById(screenId);
  if (target) {
    target.classList.add('active');
    target.style.display = 'flex';
  }
  // Update bottom nav
  document.querySelectorAll('.bottom-nav a').forEach(a => a.classList.remove('active'));
  document.querySelector('.bottom-nav a[data-screen="' + screenId + '"]')?.classList.add('active');
}
// Initialize
document.addEventListener('DOMContentLoaded', () => navigateTo('${_screens.isNotEmpty ? _screens.first.id : 'home'}'));
```

6. **CSS Requirements**:
```css
* { box-sizing: border-box; margin: 0; padding: 0; }
body { 
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: #f5f5f5;
  min-height: 100vh;
  overflow-x: hidden;
}
.screen { 
  display: none; 
  flex-direction: column;
  min-height: 100vh;
  padding-bottom: 70px; /* Space for bottom nav */
}
.screen.active { display: flex; }
.app-header {
  position: sticky;
  top: 0;
  background: ${colors[0]};
  color: white;
  padding: 16px;
  z-index: 100;
}
.screen-content {
  flex: 1;
  padding: 16px;
  overflow-y: auto;
}
.bottom-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  display: flex;
  justify-content: space-around;
  padding: 8px 0 max(8px, env(safe-area-inset-bottom));
  box-shadow: 0 -2px 10px rgba(0,0,0,0.1);
  z-index: 1000;
}
.bottom-nav a {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-decoration: none;
  color: #666;
  font-size: 12px;
  padding: 8px 16px;
}
.bottom-nav a.active { color: ${colors[0]}; }
.bottom-nav a span { font-size: 24px; margin-bottom: 4px; }
```

7. **Mobile UI Components**:
   - Cards with rounded corners and shadows
   - List items with chevron indicators
   - Floating action buttons (FAB)
   - Pull-to-refresh indicators (visual only)
   - Status bar safe area padding
   - Touch ripple effects on buttons

8. **Content Requirements**:
   - Realistic mobile app content
   - Profile avatars, stats cards, list views
   - Use emoji icons (📊 📱 ⚙️ 👤 🏠 🔔 etc.)
   - Form inputs with mobile keyboard hints

**Style Guidelines for "$_selectedStyle" (Mobile):**
${_getStyleGuidelines()}

**Output Format:**
Return ONLY the complete HTML starting with <!DOCTYPE html> and ending with </html>.
Include viewport meta tag: <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
NO markdown code blocks. NO explanations. JUST the HTML.''';
  }

  String _getStyleGuidelines() {
    switch (_selectedStyle) {
      case 'modern':
        return 'Clean iOS/Material hybrid, subtle shadows, rounded corners (12-16px), card-based layouts, system fonts';
      case 'minimal':
        return 'Maximum whitespace, simple typography, monochrome with single accent, thin separators';
      case 'glassmorphism':
        return 'Frosted glass cards (backdrop-filter: blur(20px)), transparency, gradient backgrounds';
      case 'dark':
        return 'Dark backgrounds (#1a1a2e, #0f0f23), neon accents, OLED-friendly blacks, glowing effects';
      case 'gradient':
        return 'Bold gradient headers, vibrant accent colors, gradient buttons and cards';
      case 'corporate':
        return 'Professional blues/grays, structured layouts, clear hierarchy, trustworthy feel';
      default:
        return 'Modern mobile app design with good contrast and touch-friendly elements';
    }
  }

  String _extractHtmlFromResponse(String response) {
    // Try to find HTML content
    var html = response;

    // Remove markdown code blocks if present
    if (html.contains('```html')) {
      final start = html.indexOf('```html') + 7;
      final end = html.lastIndexOf('```');
      if (end > start) {
        html = html.substring(start, end);
      }
    } else if (html.contains('```')) {
      final start = html.indexOf('```') + 3;
      final end = html.lastIndexOf('```');
      if (end > start) {
        html = html.substring(start, end);
      }
    }

    // Find DOCTYPE or html tag
    final doctypeIndex = html.toLowerCase().indexOf('<!doctype');
    final htmlIndex = html.toLowerCase().indexOf('<html');
    final startIndex =
        doctypeIndex >= 0 ? doctypeIndex : (htmlIndex >= 0 ? htmlIndex : -1);

    if (startIndex >= 0) {
      html = html.substring(startIndex);
    }

    // Find closing html tag
    final endIndex = html.toLowerCase().lastIndexOf('</html>');
    if (endIndex >= 0) {
      html = html.substring(0, endIndex + 7);
    }

    return html.trim();
  }

  Future<void> _captureScreenshot() async {
    setState(() => _isCapturing = true);

    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        setState(() => _screenshot = image);

        // Save to file
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${directory.path}/prototype_$timestamp.png');
        await file.writeAsBytes(image);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(LucideIcons.check, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Screenshot saved!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _exportHtml() async {
    if (_fullPrototypeHtml == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/prototype_$timestamp.html');
      await file.writeAsString(_fullPrototypeHtml!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${file.path}'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveAsDesignNote() async {
    if (_fullPrototypeHtml == null) return;

    setState(() => _isSaving = true);

    try {
      String screenshotPath = '';

      // Save screenshot if captured
      if (_screenshot != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        screenshotPath = '${directory.path}/prototype_$timestamp.png';
        final file = File(screenshotPath);
        await file.writeAsBytes(_screenshot!);
      }

      // Build screen list for the note
      final screenList = _screens
          .map((s) => '- **${s.name}** (${s.id}): ${s.description}')
          .join('\n');

      const codeBlockStart = '```html';
      const codeBlockEnd = '```';
      final designContent = '''## 🎨 Full Project Prototype

**Type:** Interactive Multi-Screen Prototype
**Style:** $_selectedStyle
**Color Scheme:** $_selectedColorScheme
**Generated:** ${DateTime.now().toIso8601String()}
**Screens:** ${_screens.length}

### Screens Included:
$screenList

${screenshotPath.isNotEmpty ? '''
### Preview Screenshot
![Prototype Preview](file://$screenshotPath)
''' : ''}

### Interactive HTML Prototype
$codeBlockStart
$_fullPrototypeHtml
$codeBlockEnd

---
*This is a fully interactive prototype. Open the HTML file in a browser to navigate between screens.*
''';

      // Save as design note
      await ref.read(planningProvider.notifier).createDesignNote(
        content: designContent,
        requirementIds: [],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.check, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Prototype saved with ${_screens.length} screens!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
