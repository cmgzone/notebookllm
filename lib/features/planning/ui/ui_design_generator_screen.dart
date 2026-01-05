import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../theme/app_theme.dart';
import '../../../core/ai/ai_provider.dart';
import '../../subscription/services/credit_manager.dart';
import '../planning_provider.dart';
import '../models/requirement.dart';

/// AI UI Design Generator Screen
/// Generates premium HTML/CSS designs based on plan context, previews in WebView, captures screenshots
class UIDesignGeneratorScreen extends ConsumerStatefulWidget {
  final String planId;

  const UIDesignGeneratorScreen({super.key, required this.planId});

  @override
  ConsumerState<UIDesignGeneratorScreen> createState() =>
      _UIDesignGeneratorScreenState();
}

class _UIDesignGeneratorScreenState
    extends ConsumerState<UIDesignGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();

  WebViewController? _webViewController;
  String? _generatedHtml;
  Uint8List? _screenshot;
  bool _isGenerating = false;
  bool _isCapturing = false;
  bool _isSaving = false;
  String _selectedStyle = 'modern';
  String _selectedColorScheme = 'purple';

  // Plan context
  List<Requirement> _selectedRequirements = [];
  bool _useExistingDesignNotes = true;
  bool _showContextPanel = true;

  final List<String> _styles = [
    'modern',
    'minimal',
    'glassmorphism',
    'neumorphism',
    'gradient',
    'dark',
    'corporate',
    'playful',
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
      ..setBackgroundColor(Colors.white);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.premiumGradient,
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.palette,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'AI UI Designer',
                              style: text.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan Context Panel
                  _buildPlanContextPanel(scheme, text),
                  const SizedBox(height: 20),

                  // Design Prompt Input
                  _buildPromptSection(scheme, text),
                  const SizedBox(height: 20),

                  // Style Selection
                  _buildStyleSelection(scheme, text),
                  const SizedBox(height: 16),

                  // Color Scheme Selection
                  _buildColorSchemeSelection(scheme, text),
                  const SizedBox(height: 24),

                  // Generate Button
                  _buildGenerateButton(scheme),
                  const SizedBox(height: 24),

                  // Preview Section
                  if (_generatedHtml != null) ...[
                    _buildPreviewSection(scheme, text),
                    const SizedBox(height: 16),

                    // Action Buttons
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

  Widget _buildPlanContextPanel(ColorScheme scheme, TextTheme text) {
    final planState = ref.watch(planningProvider);
    final plan = planState.currentPlan;

    if (plan == null) {
      return const SizedBox.shrink();
    }

    final requirements = plan.requirements;
    final designNotes = plan.designNotes;

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _showContextPanel = !_showContextPanel),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(LucideIcons.fileText, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan Context: ${plan.title}',
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${requirements.length} requirements • ${designNotes.length} design notes',
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showContextPanel
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_showContextPanel) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use existing design notes toggle
                  if (designNotes.isNotEmpty) ...[
                    SwitchListTile(
                      title: const Text('Use existing design notes as context'),
                      subtitle:
                          Text('${designNotes.length} design notes available'),
                      value: _useExistingDesignNotes,
                      onChanged: (v) =>
                          setState(() => _useExistingDesignNotes = v),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Requirements selection
                  if (requirements.isNotEmpty) ...[
                    Text(
                      'Select requirements to design for:',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: requirements.length,
                        itemBuilder: (context, index) {
                          final req = requirements[index];
                          final isSelected =
                              _selectedRequirements.contains(req);
                          return CheckboxListTile(
                            title: Text(
                              req.title,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              req.earsPattern.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.primary,
                              ),
                            ),
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedRequirements.add(req);
                                } else {
                                  _selectedRequirements.remove(req);
                                }
                              });
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick select buttons
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() =>
                              _selectedRequirements = List.from(requirements)),
                          icon: const Icon(LucideIcons.checkSquare, size: 16),
                          label: const Text('Select All'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _selectedRequirements.clear()),
                          icon: const Icon(LucideIcons.square, size: 16),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.info,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No requirements yet. Add requirements in the plan to use them as design context.',
                              style: text.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildPromptSection(ColorScheme scheme, TextTheme text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Describe Your Design',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'e.g., A modern dashboard with user stats, charts, and a sidebar navigation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: scheme.surface,
              ),
            ),
            const SizedBox(height: 12),
            // Quick prompts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickPrompt('Landing Page', scheme),
                _buildQuickPrompt('Dashboard', scheme),
                _buildQuickPrompt('Login Form', scheme),
                _buildQuickPrompt('Pricing Cards', scheme),
                _buildQuickPrompt('Profile Card', scheme),
                _buildQuickPrompt('Feature Section', scheme),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildQuickPrompt(String label, ColorScheme scheme) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _promptController.text = 'Create a premium $label design';
      },
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.3),
    );
  }

  Widget _buildStyleSelection(ColorScheme scheme, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Design Style',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _styles.length,
            itemBuilder: (context, index) {
              final style = _styles[index];
              final isSelected = style == _selectedStyle;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    style.substring(0, 1).toUpperCase() + style.substring(1),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedStyle = style);
                    }
                  },
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : scheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildColorSchemeSelection(ColorScheme scheme, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                onTap: () => setState(() => _selectedColorScheme = entry.key),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: entry.value
                          .map((c) =>
                              Color(int.parse(c.replaceFirst('#', '0xFF'))))
                          .toList(),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Color(int.parse(
                                      entry.value[0].replaceFirst('#', '0xFF')))
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildGenerateButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _isGenerating ? null : _generateDesign,
        icon: _isGenerating
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : const Icon(LucideIcons.wand2),
        label: Text(_isGenerating ? 'Generating...' : 'Generate Design'),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).scale();
  }

  Widget _buildPreviewSection(ColorScheme scheme, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.eye, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Live Preview',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_screenshot != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.check,
                        color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Screenshot captured',
                      style:
                          TextStyle(color: Colors.green.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // WebView Preview
        Screenshot(
          controller: _screenshotController,
          child: Container(
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: WebViewWidget(controller: _webViewController!),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
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
            label: Text(_isCapturing ? 'Capturing...' : 'Capture Screenshot'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: (_isSaving || _generatedHtml == null)
                ? null
                : _saveAsDesignNote,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save Design'),
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

  Future<void> _generateDesign() async {
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your design')),
      );
      return;
    }

    // Check credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.chatMessage * 3,
      feature: 'ui_design_generator',
    );
    if (!hasCredits) return;

    setState(() {
      _isGenerating = true;
      _screenshot = null;
    });

    try {
      final colors = _colorSchemes[_selectedColorScheme]!;
      final prompt = _buildDesignPrompt(colors);

      final aiNotifier = ref.read(aiProvider.notifier);
      await aiNotifier.generateContent(prompt, style: ChatStyle.standard);

      final aiState = ref.read(aiProvider);
      if (aiState.error != null) {
        throw Exception(aiState.error);
      }

      final response = aiState.lastResponse ?? '';
      final html = _extractHtmlFromResponse(response);

      if (html.isNotEmpty) {
        setState(() => _generatedHtml = html);
        await _webViewController?.loadHtmlString(html);
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

  String _buildDesignPrompt(List<String> colors) {
    final planState = ref.read(planningProvider);
    final plan = planState.currentPlan;

    // Build context from selected requirements
    String requirementsContext = '';
    if (_selectedRequirements.isNotEmpty) {
      requirementsContext = '''

**Selected Requirements to Design For:**
${_selectedRequirements.map((r) => '''
- **${r.title}**
  ${r.description.isNotEmpty ? 'Description: ${r.description}' : ''}
  ${r.acceptanceCriteria.isNotEmpty ? 'Acceptance Criteria: ${r.acceptanceCriteria.join(", ")}' : ''}
''').join('\n')}
''';
    }

    // Build context from existing design notes
    String designNotesContext = '';
    if (_useExistingDesignNotes &&
        plan != null &&
        plan.designNotes.isNotEmpty) {
      final relevantNotes =
          plan.designNotes.take(3).toList(); // Limit to 3 most recent
      designNotesContext = '''

**Existing Design Decisions (for consistency):**
${relevantNotes.map((n) => '- ${n.content.length > 200 ? '${n.content.substring(0, 200)}...' : n.content}').join('\n')}
''';
    }

    // Build plan context
    String planContext = '';
    if (plan != null) {
      planContext = '''

**Project Context:**
- Project: ${plan.title}
- Description: ${plan.description.isNotEmpty ? plan.description : 'N/A'}
''';
    }

    return '''Generate a complete, self-contained HTML page with embedded CSS for the following design:

**Design Request:** ${_promptController.text}
$planContext
$requirementsContext
$designNotesContext
**Style:** $_selectedStyle
**Primary Color:** ${colors[0]}
**Secondary Color:** ${colors[1]}
**Accent Color:** ${colors[2]}

**Requirements:**
1. Create a premium, professional UI design
2. Use modern CSS techniques (flexbox, grid, gradients, shadows)
3. Include smooth transitions and hover effects
4. Make it responsive and mobile-friendly
5. Use the specified color scheme throughout
6. Add realistic placeholder content based on the project context
7. Include icons using emoji or Unicode symbols
8. The design should look polished and production-ready
9. If requirements are provided, ensure the UI addresses those specific features

**Style Guidelines for "$_selectedStyle":**
${_getStyleGuidelines()}

**Output Format:**
Return ONLY the complete HTML code starting with <!DOCTYPE html> and ending with </html>.
Do not include any explanations or markdown code blocks.
The HTML must be self-contained with all CSS in a <style> tag.''';
  }

  String _getStyleGuidelines() {
    switch (_selectedStyle) {
      case 'modern':
        return 'Clean lines, subtle shadows, rounded corners, whitespace, sans-serif fonts';
      case 'minimal':
        return 'Maximum whitespace, simple typography, monochrome accents, no decorations';
      case 'glassmorphism':
        return 'Frosted glass effect, blur backgrounds, transparency, light borders';
      case 'neumorphism':
        return 'Soft shadows, extruded elements, subtle gradients, tactile feel';
      case 'gradient':
        return 'Bold gradients, vibrant colors, dynamic backgrounds, modern feel';
      case 'dark':
        return 'Dark backgrounds, neon accents, high contrast, sleek appearance';
      case 'corporate':
        return 'Professional, trustworthy, structured layout, business-appropriate';
      case 'playful':
        return 'Rounded shapes, bright colors, fun animations, friendly feel';
      default:
        return 'Modern and professional';
    }
  }

  String _extractHtmlFromResponse(String response) {
    // Try to extract HTML from the response
    String html = response.trim();

    // Remove markdown code blocks if present
    if (html.contains('```html')) {
      final start = html.indexOf('```html') + 7;
      final end = html.lastIndexOf('```');
      if (end > start) {
        html = html.substring(start, end).trim();
      }
    } else if (html.contains('```')) {
      final start = html.indexOf('```') + 3;
      final end = html.lastIndexOf('```');
      if (end > start) {
        html = html.substring(start, end).trim();
      }
    }

    // Ensure it starts with DOCTYPE or html tag
    if (!html.toLowerCase().startsWith('<!doctype') &&
        !html.toLowerCase().startsWith('<html')) {
      // Try to find the start of HTML
      final doctypeIndex = html.toLowerCase().indexOf('<!doctype');
      final htmlIndex = html.toLowerCase().indexOf('<html');
      final startIndex =
          doctypeIndex >= 0 ? doctypeIndex : (htmlIndex >= 0 ? htmlIndex : -1);
      if (startIndex >= 0) {
        html = html.substring(startIndex);
      }
    }

    return html;
  }

  Future<void> _captureScreenshot() async {
    setState(() => _isCapturing = true);

    try {
      // Wait a moment for WebView to fully render
      await Future.delayed(const Duration(milliseconds: 500));

      final image = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );

      if (image != null) {
        setState(() => _screenshot = image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screenshot captured successfully!'),
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

  Future<void> _saveAsDesignNote() async {
    if (_generatedHtml == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate a design first')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String screenshotPath = '';

      // Save screenshot to file if captured
      if (_screenshot != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        screenshotPath = '${directory.path}/design_$timestamp.png';
        final file = File(screenshotPath);
        await file.writeAsBytes(_screenshot!);
      }

      // Build requirements context for the note
      String requirementsSection = '';
      if (_selectedRequirements.isNotEmpty) {
        requirementsSection = '''
### Designed For Requirements:
${_selectedRequirements.map((r) => '- ${r.title}').join('\n')}
''';
      }

      // Create design note content with HTML and screenshot reference
      final codeBlockStart = '```html';
      final codeBlockEnd = '```';
      final designContent = '''## 🎨 UI Design: ${_promptController.text}

**Type:** UI Design (HTML/CSS)
**Style:** $_selectedStyle
**Color Scheme:** $_selectedColorScheme
**Generated:** ${DateTime.now().toIso8601String()}
$requirementsSection
${screenshotPath.isNotEmpty ? '''
### Screenshot
![Design Preview](file://$screenshotPath)
''' : ''}
### HTML Code
$codeBlockStart
$_generatedHtml
$codeBlockEnd

---
*This UI design was generated by AI UI Designer and can be used as a reference for implementation.*
''';

      // Get requirement IDs for linking
      final requirementIds = _selectedRequirements.map((r) => r.id).toList();

      // Save as design note
      await ref.read(planningProvider.notifier).createDesignNote(
            content: designContent,
            requirementIds: requirementIds,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.check, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Design saved! ${requirementIds.isNotEmpty ? "Linked to ${requirementIds.length} requirement(s)" : ""}',
                  ),
                ),
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
