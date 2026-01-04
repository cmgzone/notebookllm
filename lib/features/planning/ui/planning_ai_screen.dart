import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';
import '../../../core/ai/ai_provider.dart';
import '../../subscription/services/credit_manager.dart';
import '../models/plan_task.dart';
import '../planning_provider.dart';

/// Planning AI chat screen for brainstorming and generating requirements/tasks.
/// Implements Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
class PlanningAIScreen extends ConsumerStatefulWidget {
  final String? planId;

  const PlanningAIScreen({super.key, this.planId});

  @override
  ConsumerState<PlanningAIScreen> createState() => _PlanningAIScreenState();
}

class _PlanningAIScreenState extends ConsumerState<PlanningAIScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_PlanningMessage> _messages = [];
  bool _isLoading = false;
  _PlanningMode _currentMode = _PlanningMode.brainstorm;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    // Add welcome message (Requirements 2.1)
    _messages.add(_PlanningMessage(
      text: _getWelcomeMessage(),
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  String _getWelcomeMessage() {
    return '''👋 **Welcome to Planning Mode AI!**

I'm here to help you brainstorm, organize ideas, and create structured plans. Here's what I can do:

🧠 **Brainstorm** - Explore and refine your ideas
📋 **Generate Requirements** - Create EARS-pattern requirements
✅ **Create Tasks** - Break down requirements into actionable tasks

**How to get started:**
1. Tell me about your project idea or goal
2. I'll help you break it down into clear requirements
3. We'll create actionable tasks from those requirements

What would you like to work on today?''';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Check credits
    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.chatMessage,
      feature: 'planning_ai_chat',
    );
    if (!hasCredits) return;

    // Add user message
    setState(() {
      _messages.add(_PlanningMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      // Generate AI response based on current mode
      final response = await _generateResponse(text);

      setState(() {
        _messages.add(_PlanningMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_PlanningMessage(
          text: '❌ Error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  /// Generate AI response based on current mode (Requirements 2.1, 2.2, 2.3)
  Future<String> _generateResponse(String userInput) async {
    final aiNotifier = ref.read(aiProvider.notifier);
    final planState = ref.read(planningProvider);
    final currentPlan = planState.currentPlan;

    // Build context from current plan if available
    String planContext = '';
    if (currentPlan != null) {
      planContext = '''
**Current Plan: ${currentPlan.title}**
${currentPlan.description.isNotEmpty ? 'Description: ${currentPlan.description}' : ''}

**Existing Requirements (${currentPlan.requirements.length}):**
${currentPlan.requirements.map((r) => '- ${r.title}').join('\n')}

**Existing Tasks (${currentPlan.tasks.length}):**
${currentPlan.tasks.map((t) => '- ${t.title} [${t.status.name}]').join('\n')}
''';
    }

    // Build conversation history
    final history = _messages
        .where((m) => !m.isError)
        .map((m) => AIPromptResponse(
              prompt: m.isUser ? m.text : '',
              response: m.isUser ? '' : m.text,
            ))
        .toList();

    String systemPrompt;
    switch (_currentMode) {
      case _PlanningMode.brainstorm:
        systemPrompt = _getBrainstormPrompt(planContext);
        break;
      case _PlanningMode.requirements:
        systemPrompt = _getRequirementsPrompt(planContext);
        break;
      case _PlanningMode.tasks:
        systemPrompt = _getTasksPrompt(planContext);
        break;
    }

    await aiNotifier.generateContent(
      '''$systemPrompt

User Input: $userInput''',
      context: [planContext],
      style: ChatStyle.standard,
      externalHistory: history,
    );

    final aiState = ref.read(aiProvider);
    if (aiState.error != null) {
      throw Exception(aiState.error);
    }

    return aiState.lastResponse ??
        'I apologize, I couldn\'t generate a response.';
  }

  String _getBrainstormPrompt(String planContext) {
    return '''You are a Planning AI assistant helping users brainstorm and refine project ideas.

**Your Role (Requirements 2.1):**
- Engage in conversation to understand the user's goals
- Ask clarifying questions to better understand the scope
- Help break down complex ideas into manageable pieces
- Suggest related considerations they might have missed
- Be encouraging and collaborative

**Context:**
$planContext

**Guidelines:**
- Keep responses focused and actionable
- Use bullet points for clarity
- Ask follow-up questions to deepen understanding
- Suggest when the user might be ready to move to requirements generation
- Use emojis sparingly for warmth

**Response Format:**
Provide a helpful, conversational response that advances the planning process.''';
  }

  String _getRequirementsPrompt(String planContext) {
    return '''You are a Planning AI assistant helping users create structured requirements following EARS patterns.

**Your Role (Requirements 2.2):**
- Help break down ideas into formal requirements
- Use EARS (Easy Approach to Requirements Syntax) patterns:
  • Ubiquitous: THE <system> SHALL <response>
  • Event-driven: WHEN <trigger>, THE <system> SHALL <response>
  • State-driven: WHILE <condition>, THE <system> SHALL <response>
  • Unwanted: IF <condition>, THEN THE <system> SHALL <response>
  • Optional: WHERE <option>, THE <system> SHALL <response>
  • Complex: Combination of above patterns

**Context:**
$planContext

**Guidelines:**
- Generate requirements that are testable and measurable
- Include acceptance criteria for each requirement
- Avoid vague terms like "quickly", "user-friendly"
- Use active voice and specific terminology
- Number requirements clearly

**Response Format:**
When generating requirements, use this format:

### Requirement [N]: [Title]
**User Story:** As a [role], I want [feature], so that [benefit]
**EARS Pattern:** [pattern type]
**Acceptance Criteria:**
1. [Criterion 1]
2. [Criterion 2]
...

Ask if the user wants to add these requirements to their plan.''';
  }

  String _getTasksPrompt(String planContext) {
    return '''You are a Planning AI assistant helping users create actionable tasks from requirements.

**Your Role (Requirements 2.3):**
- Break down requirements into discrete, actionable tasks
- Ensure tasks are specific and achievable
- Suggest appropriate priority levels
- Identify dependencies between tasks

**Context:**
$planContext

**Guidelines:**
- Each task should be completable in a reasonable timeframe
- Include clear descriptions of what needs to be done
- Reference which requirements each task addresses
- Suggest sub-tasks for complex items
- Consider the logical order of implementation

**Response Format:**
When generating tasks, use this format:

### Task [N]: [Title]
**Description:** [What needs to be done]
**Priority:** [Low/Medium/High/Critical]
**Requirements:** [Which requirements this addresses]
**Sub-tasks (if any):**
- [ ] Sub-task 1
- [ ] Sub-task 2

Ask if the user wants to add these tasks to their plan.''';
  }

  /// Generate requirements from the conversation (Requirements 2.2)
  Future<void> _generateRequirements() async {
    if (_isLoading) return;

    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.chatMessage * 2,
      feature: 'planning_generate_requirements',
    );
    if (!hasCredits) return;

    setState(() => _isLoading = true);

    try {
      // Gather conversation context
      final conversationSummary =
          _messages.where((m) => m.isUser).map((m) => m.text).join('\n');

      final prompt =
          '''Based on our conversation, generate structured requirements following EARS patterns.

**Conversation Summary:**
$conversationSummary

**Instructions:**
1. Identify the key features and functionalities discussed
2. Create formal requirements using EARS patterns
3. Include acceptance criteria for each requirement
4. Number requirements sequentially

Generate 3-5 requirements that capture the core functionality discussed.''';

      final aiNotifier = ref.read(aiProvider.notifier);
      await aiNotifier.generateContent(
        prompt,
        style: ChatStyle.standard,
      );

      final aiState = ref.read(aiProvider);
      if (aiState.error != null) {
        throw Exception(aiState.error);
      }

      final response = aiState.lastResponse ?? '';

      setState(() {
        _messages.add(_PlanningMessage(
          text: '📋 **Generated Requirements:**\n\n$response',
          isUser: false,
          timestamp: DateTime.now(),
          hasActions: true,
          actionType: _ActionType.requirements,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_PlanningMessage(
          text: '❌ Failed to generate requirements: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }
  }

  /// Generate tasks from requirements (Requirements 2.3)
  Future<void> _generateTasks() async {
    if (_isLoading) return;

    final hasCredits = await ref.tryUseCredits(
      context: context,
      amount: CreditCosts.chatMessage * 2,
      feature: 'planning_generate_tasks',
    );
    if (!hasCredits) return;

    final planState = ref.read(planningProvider);
    final currentPlan = planState.currentPlan;

    if (currentPlan == null || currentPlan.requirements.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please add requirements first before generating tasks'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final requirementsList = currentPlan.requirements
          .map((r) =>
              '${r.title}: ${r.description}\nAcceptance Criteria: ${r.acceptanceCriteria.join(", ")}')
          .join('\n\n');

      final prompt = '''Generate actionable tasks from these requirements:

**Requirements:**
$requirementsList

**Instructions:**
1. Break down each requirement into discrete tasks
2. Assign appropriate priority levels
3. Identify any dependencies
4. Suggest sub-tasks for complex items

Generate tasks that will fully implement all requirements.''';

      final aiNotifier = ref.read(aiProvider.notifier);
      await aiNotifier.generateContent(
        prompt,
        style: ChatStyle.standard,
      );

      final aiState = ref.read(aiProvider);
      if (aiState.error != null) {
        throw Exception(aiState.error);
      }

      final response = aiState.lastResponse ?? '';

      setState(() {
        _messages.add(_PlanningMessage(
          text: '✅ **Generated Tasks:**\n\n$response',
          isUser: false,
          timestamp: DateTime.now(),
          hasActions: true,
          actionType: _ActionType.tasks,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_PlanningMessage(
          text: '❌ Failed to generate tasks: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }
  }

  /// Show dialog to add generated content to plan (Requirements 2.4)
  void _showAddToplanDialog(_ActionType type) {
    final planState = ref.read(planningProvider);
    final currentPlan = planState.currentPlan;

    if (currentPlan == null) {
      _showCreatePlanFirstDialog();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              type == _ActionType.requirements
                  ? LucideIcons.fileText
                  : LucideIcons.listChecks,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(type == _ActionType.requirements
                ? 'Add Requirements'
                : 'Add Tasks'),
          ],
        ),
        content: Text(
          'Add the generated ${type == _ActionType.requirements ? 'requirements' : 'tasks'} '
          'to "${currentPlan.title}"?\n\n'
          'You can edit them later from the plan detail screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addGeneratedContentToPlan(type);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlanFirstDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertCircle, color: Colors.orange),
            SizedBox(width: 12),
            Text('No Plan Selected'),
          ],
        ),
        content: const Text(
          'Please create or select a plan first before adding requirements or tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addGeneratedContentToPlan(_ActionType type) async {
    final planState = ref.read(planningProvider);
    final currentPlan = planState.currentPlan;

    if (currentPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No plan selected')),
      );
      return;
    }

    // Find the last AI message with generated content
    final lastGeneratedMessage = _messages.reversed.firstWhere(
      (m) => !m.isUser && m.hasActions && m.actionType == type,
      orElse: () => _PlanningMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    if (lastGeneratedMessage.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No generated content found')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (type == _ActionType.requirements) {
        // Parse and add requirements
        final requirements =
            _parseRequirementsFromMarkdown(lastGeneratedMessage.text);
        if (requirements.isEmpty) {
          throw Exception('Could not parse any requirements from the response');
        }

        final planningNotifier = ref.read(planningProvider.notifier);
        for (final req in requirements) {
          await planningNotifier.createRequirement(
            title: req['title'] as String,
            description: req['description'] as String?,
            earsPattern: req['earsPattern'] as String?,
            acceptanceCriteria:
                (req['acceptanceCriteria'] as List<String>?) ?? [],
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${requirements.length} requirements to plan'),
            action: SnackBarAction(
              label: 'View Plan',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      } else {
        // Parse and add tasks
        final tasks = _parseTasksFromMarkdown(lastGeneratedMessage.text);
        if (tasks.isEmpty) {
          throw Exception('Could not parse any tasks from the response');
        }

        final planningNotifier = ref.read(planningProvider.notifier);
        for (final task in tasks) {
          await planningNotifier.createTask(
            title: task['title'] as String,
            description: task['description'] as String?,
            priority: _parsePriority(task['priority'] as String?),
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${tasks.length} tasks to plan'),
            action: SnackBarAction(
              label: 'View Plan',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }

      // Reload the plan to show updated content
      await ref.read(planningProvider.notifier).loadPlan(currentPlan.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Parse requirements from AI-generated markdown
  List<Map<String, dynamic>> _parseRequirementsFromMarkdown(String markdown) {
    final requirements = <Map<String, dynamic>>[];

    // Pattern to match requirement blocks
    // ### Requirement [N]: [Title]
    final reqPattern = RegExp(
      r'###\s*Requirement\s*\[?\d+\]?:?\s*(.+?)(?=\n)',
      caseSensitive: false,
    );

    // Find all requirement headers
    final matches = reqPattern.allMatches(markdown);

    for (final match in matches) {
      final title = match.group(1)?.trim() ?? '';
      if (title.isEmpty) continue;

      // Get the content after this header until the next header or end
      final startIndex = match.end;
      final nextMatch =
          reqPattern.allMatches(markdown.substring(startIndex)).firstOrNull;
      final endIndex =
          nextMatch != null ? startIndex + nextMatch.start : markdown.length;
      final content = markdown.substring(startIndex, endIndex);

      // Extract description (User Story or general description)
      String? description;
      final userStoryMatch =
          RegExp(r'\*\*User Story:\*\*\s*(.+?)(?=\n\*\*|\n###|$)', dotAll: true)
              .firstMatch(content);
      if (userStoryMatch != null) {
        description = userStoryMatch.group(1)?.trim();
      }

      // Extract EARS pattern
      String? earsPattern;
      final patternMatch =
          RegExp(r'\*\*EARS Pattern:\*\*\s*(\w+)', caseSensitive: false)
              .firstMatch(content);
      if (patternMatch != null) {
        final pattern = patternMatch.group(1)?.toLowerCase();
        if (['ubiquitous', 'event', 'state', 'unwanted', 'optional', 'complex']
            .contains(pattern)) {
          earsPattern = pattern;
        }
      }

      // Extract acceptance criteria
      final acceptanceCriteria = <String>[];
      final criteriaMatch = RegExp(
              r'\*\*Acceptance Criteria:\*\*(.+?)(?=\n###|\n\*\*[A-Z]|$)',
              dotAll: true)
          .firstMatch(content);
      if (criteriaMatch != null) {
        final criteriaText = criteriaMatch.group(1) ?? '';
        final criteriaLines = RegExp(r'^\s*\d+\.\s*(.+)$', multiLine: true)
            .allMatches(criteriaText);
        for (final line in criteriaLines) {
          final criterion = line.group(1)?.trim();
          if (criterion != null && criterion.isNotEmpty) {
            acceptanceCriteria.add(criterion);
          }
        }
      }

      requirements.add({
        'title': title,
        'description': description,
        'earsPattern': earsPattern,
        'acceptanceCriteria': acceptanceCriteria,
      });
    }

    return requirements;
  }

  /// Parse tasks from AI-generated markdown
  List<Map<String, dynamic>> _parseTasksFromMarkdown(String markdown) {
    final tasks = <Map<String, dynamic>>[];

    // Pattern to match task blocks
    // ### Task [N]: [Title]
    final taskPattern = RegExp(
      r'###\s*Task\s*\[?\d+\]?:?\s*(.+?)(?=\n)',
      caseSensitive: false,
    );

    // Find all task headers
    final matches = taskPattern.allMatches(markdown);

    for (final match in matches) {
      final title = match.group(1)?.trim() ?? '';
      if (title.isEmpty) continue;

      // Get the content after this header until the next header or end
      final startIndex = match.end;
      final nextMatch =
          taskPattern.allMatches(markdown.substring(startIndex)).firstOrNull;
      final endIndex =
          nextMatch != null ? startIndex + nextMatch.start : markdown.length;
      final content = markdown.substring(startIndex, endIndex);

      // Extract description
      String? description;
      final descMatch = RegExp(
              r'\*\*Description:\*\*\s*(.+?)(?=\n\*\*|\n###|$)',
              dotAll: true)
          .firstMatch(content);
      if (descMatch != null) {
        description = descMatch.group(1)?.trim();
      }

      // Extract priority
      String? priority;
      final priorityMatch =
          RegExp(r'\*\*Priority:\*\*\s*(\w+)', caseSensitive: false)
              .firstMatch(content);
      if (priorityMatch != null) {
        priority = priorityMatch.group(1)?.toLowerCase();
      }

      tasks.add({
        'title': title,
        'description': description,
        'priority': priority,
      });
    }

    return tasks;
  }

  TaskPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'critical':
        return TaskPriority.critical;
      default:
        return TaskPriority.medium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final planState = ref.watch(planningProvider);
    final currentPlan = planState.currentPlan;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient header
          SliverAppBar(
            floating: false,
            pinned: true,
            expandedHeight: 140,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                ),
                child: Stack(
                  children: [
                    // Decorative elements
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.brain,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Planning AI',
                                        style: text.titleLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (currentPlan != null)
                                        Text(
                                          currentPlan.title,
                                          style: text.bodySmall?.copyWith(
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ).animate().fadeIn().slideX(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // Mode selector
              PopupMenuButton<_PlanningMode>(
                icon: const Icon(Icons.tune, color: Colors.white),
                tooltip: 'Planning Mode',
                onSelected: (mode) => setState(() => _currentMode = mode),
                itemBuilder: (ctx) => [
                  _buildModeMenuItem(
                    _PlanningMode.brainstorm,
                    LucideIcons.lightbulb,
                    'Brainstorm',
                    'Explore and refine ideas',
                  ),
                  _buildModeMenuItem(
                    _PlanningMode.requirements,
                    LucideIcons.fileText,
                    'Requirements',
                    'Generate EARS requirements',
                  ),
                  _buildModeMenuItem(
                    _PlanningMode.tasks,
                    LucideIcons.listChecks,
                    'Tasks',
                    'Create actionable tasks',
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _messages.clear();
                    _initializeChat();
                  });
                },
                tooltip: 'Clear Chat',
              ),
            ],
          ),

          // Mode indicator
          SliverToBoxAdapter(
            child: _ModeIndicator(
              currentMode: _currentMode,
              onModeChanged: (mode) => setState(() => _currentMode = mode),
            ),
          ),

          // Messages list
          SliverFillRemaining(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return const _TypingIndicator();
                      }
                      final message = _messages[index];
                      return _MessageBubble(
                        message: message,
                        onAddToPlan: message.hasActions
                            ? () => _showAddToplanDialog(message.actionType!)
                            : null,
                      ).animate().fadeIn(
                            delay: Duration(milliseconds: index * 50),
                          );
                    },
                  ),
                ),

                // Quick actions
                _QuickActionsBar(
                  onGenerateRequirements: _generateRequirements,
                  onGenerateTasks: _generateTasks,
                  isLoading: _isLoading,
                  currentMode: _currentMode,
                ),

                // Input area
                _ChatInputArea(
                  controller: _controller,
                  onSend: _sendMessage,
                  isLoading: _isLoading,
                  currentMode: _currentMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_PlanningMode> _buildModeMenuItem(
    _PlanningMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = _currentMode == mode;
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? scheme.primary : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? scheme.primary : null,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(LucideIcons.check, size: 16, color: scheme.primary),
        ],
      ),
    );
  }
}

// ==================== ENUMS ====================

enum _PlanningMode {
  brainstorm,
  requirements,
  tasks,
}

enum _ActionType {
  requirements,
  tasks,
}

// ==================== DATA CLASSES ====================

class _PlanningMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool hasActions;
  final _ActionType? actionType;

  _PlanningMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.hasActions = false,
    this.actionType,
  });
}

// ==================== WIDGETS ====================

/// Mode indicator showing current planning mode
class _ModeIndicator extends StatelessWidget {
  final _PlanningMode currentMode;
  final ValueChanged<_PlanningMode> onModeChanged;

  const _ModeIndicator({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: scheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          _ModeChip(
            icon: LucideIcons.lightbulb,
            label: 'Brainstorm',
            isSelected: currentMode == _PlanningMode.brainstorm,
            onTap: () => onModeChanged(_PlanningMode.brainstorm),
          ),
          const SizedBox(width: 8),
          _ModeChip(
            icon: LucideIcons.fileText,
            label: 'Requirements',
            isSelected: currentMode == _PlanningMode.requirements,
            onTap: () => onModeChanged(_PlanningMode.requirements),
          ),
          const SizedBox(width: 8),
          _ModeChip(
            icon: LucideIcons.listChecks,
            label: 'Tasks',
            isSelected: currentMode == _PlanningMode.tasks,
            onTap: () => onModeChanged(_PlanningMode.tasks),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message bubble widget
class _MessageBubble extends StatelessWidget {
  final _PlanningMessage message;
  final VoidCallback? onAddToPlan;

  const _MessageBubble({
    required this.message,
    this.onAddToPlan,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? scheme.primary
                    : message.isError
                        ? scheme.errorContainer
                        : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser
                        ? scheme.onPrimary
                        : message.isError
                            ? scheme.onErrorContainer
                            : scheme.onSurface,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  strong: TextStyle(
                    color: isUser ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: TextStyle(
                    color: isUser ? scheme.onPrimary : scheme.onSurface,
                  ),
                  h3: TextStyle(
                    color: isUser ? scheme.onPrimary : scheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(Uri.parse(href));
                  }
                },
              ),
            ),
            // Action buttons for generated content
            if (message.hasActions && onAddToPlan != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onAddToPlan,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: Text(
                      message.actionType == _ActionType.requirements
                          ? 'Add to Plan'
                          : 'Add Tasks',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Typing indicator widget
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            SizedBox(width: 4),
            _TypingDot(delay: 150),
            SizedBox(width: 4),
            _TypingDot(delay: 300),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.3, 1.3),
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: delay),
        )
        .fadeIn(
          duration: const Duration(milliseconds: 200),
          delay: Duration(milliseconds: delay),
        );
  }
}

/// Quick actions bar for generating content
class _QuickActionsBar extends StatelessWidget {
  final VoidCallback onGenerateRequirements;
  final VoidCallback onGenerateTasks;
  final bool isLoading;
  final _PlanningMode currentMode;

  const _QuickActionsBar({
    required this.onGenerateRequirements,
    required this.onGenerateTasks,
    required this.isLoading,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _QuickActionButton(
              icon: LucideIcons.fileText,
              label: 'Generate Requirements',
              onTap: isLoading ? null : onGenerateRequirements,
              isHighlighted: currentMode == _PlanningMode.requirements,
            ),
            const SizedBox(width: 8),
            _QuickActionButton(
              icon: LucideIcons.listChecks,
              label: 'Generate Tasks',
              onTap: isLoading ? null : onGenerateTasks,
              isHighlighted: currentMode == _PlanningMode.tasks,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isHighlighted
                ? scheme.primary.withValues(alpha: 0.1)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted
                  ? scheme.primary.withValues(alpha: 0.5)
                  : scheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isEnabled
                    ? (isHighlighted ? scheme.primary : scheme.onSurface)
                    : scheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isHighlighted ? FontWeight.w600 : FontWeight.normal,
                  color: isEnabled
                      ? (isHighlighted ? scheme.primary : scheme.onSurface)
                      : scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat input area
class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final _PlanningMode currentMode;

  const _ChatInputArea({
    required this.controller,
    required this.onSend,
    required this.isLoading,
    required this.currentMode,
  });

  String _getHintText() {
    switch (currentMode) {
      case _PlanningMode.brainstorm:
        return 'Describe your project idea...';
      case _PlanningMode.requirements:
        return 'What features do you need?';
      case _PlanningMode.tasks:
        return 'What tasks should be created?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: _getHintText(),
                  hintStyle: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton.filled(
              onPressed: isLoading ? null : onSend,
              icon: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(LucideIcons.send),
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
