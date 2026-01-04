import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../theme/app_theme.dart';
import '../models/plan.dart';
import '../models/plan_task.dart';
import '../models/requirement.dart';
import '../planning_provider.dart';
import 'plan_sharing_sheet.dart';
import 'task_list_widget.dart';

/// Plan detail screen showing requirements, design notes, tasks sections.
/// Implements Requirements: 1.3, 4.1, 8.1
class PlanDetailScreen extends ConsumerStatefulWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load plan details on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(planningProvider.notifier).loadPlan(widget.planId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planningProvider);
    final plan = state.currentPlan;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient header
          SliverAppBar(
            floating: false,
            pinned: true,
            expandedHeight: 200,
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
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 100,
                        height: 100,
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
                            if (plan != null) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(plan.status),
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      plan.title,
                                      style: text.headlineSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn().slideX(),
                              if (plan.description.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  plan.description,
                                  style: text.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ).animate().fadeIn(delay: 100.ms).slideX(),
                              ],
                              const SizedBox(height: 12),
                              // Progress indicator
                              _ProgressIndicator(
                                percentage: plan.completionPercentage,
                              ).animate().fadeIn(delay: 200.ms),
                            ] else ...[
                              Text(
                                'Loading...',
                                style: text.headlineSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
              onPressed: () => context.pop(),
            ),
            actions: [
              // Connection status indicator
              _ConnectionIndicator(isConnected: state.isConnected),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () =>
                    ref.read(planningProvider.notifier).loadPlan(widget.planId),
                tooltip: 'Refresh',
              ),
              if (plan != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) => _handleMenuAction(value, plan),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(LucideIcons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Plan'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(LucideIcons.share2, size: 18),
                          SizedBox(width: 8),
                          Text('Share with Agent'),
                        ],
                      ),
                    ),
                    if (plan.status != PlanStatus.archived)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(LucideIcons.archive, size: 18),
                            SizedBox(width: 8),
                            Text('Archive'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2,
                              size: 18, color: scheme.error),
                          const SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: scheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.listChecks, size: 18),
                      const SizedBox(width: 8),
                      Text('Tasks (${plan?.tasks.length ?? 0})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.fileText, size: 18),
                      const SizedBox(width: 8),
                      Text('Requirements (${plan?.requirements.length ?? 0})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.lightbulb, size: 18),
                      const SizedBox(width: 8),
                      Text('Design (${plan?.designNotes.length ?? 0})'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error message
          if (state.error != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertCircle, color: scheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () =>
                          ref.read(planningProvider.notifier).clearError(),
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator
          if (state.isLoadingTasks)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (plan != null)
            // Tab content
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tasks tab
                  _TasksSection(plan: plan),
                  // Requirements tab
                  _RequirementsSection(requirements: plan.requirements),
                  // Design notes tab
                  _DesignNotesSection(designNotes: plan.designNotes),
                ],
              ),
            )
          else
            const SliverToBoxAdapter(
              child: _EmptyState(
                icon: LucideIcons.fileQuestion,
                title: 'Plan Not Found',
                subtitle: 'The plan you\'re looking for doesn\'t exist',
              ),
            ),
        ],
      ),
      floatingActionButton: plan != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AI Assistant FAB
                FloatingActionButton(
                  heroTag: 'planning_ai',
                  onPressed: () => context.push('/planning/${plan.id}/ai'),
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: const Icon(LucideIcons.brain),
                ).animate().scale(delay: 200.ms),
                const SizedBox(height: 12),
                // Add Task FAB
                FloatingActionButton.extended(
                  heroTag: 'add_task',
                  onPressed: () => _showAddTaskDialog(context, plan),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add Task'),
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ).animate().scale(delay: 300.ms),
              ],
            )
          : null,
    );
  }

  IconData _getStatusIcon(PlanStatus status) {
    switch (status) {
      case PlanStatus.draft:
        return LucideIcons.fileEdit;
      case PlanStatus.active:
        return LucideIcons.play;
      case PlanStatus.completed:
        return LucideIcons.checkCircle;
      case PlanStatus.archived:
        return LucideIcons.archive;
    }
  }

  void _handleMenuAction(String action, Plan plan) {
    switch (action) {
      case 'edit':
        _showEditPlanDialog(context, plan);
        break;
      case 'share':
        _showShareDialog(context, plan);
        break;
      case 'archive':
        _archivePlan(plan);
        break;
      case 'delete':
        _confirmDeletePlan(plan);
        break;
    }
  }

  void _showEditPlanDialog(BuildContext context, Plan plan) {
    final titleController = TextEditingController(text: plan.title);
    final descController = TextEditingController(text: plan.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.edit),
            SizedBox(width: 12),
            Text('Edit Plan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(LucideIcons.type),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(LucideIcons.alignLeft),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(planningProvider.notifier).updatePlan(
                    plan.id,
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                  );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context, Plan plan) {
    // Implements Requirements 7.1, 7.2: Agent access management
    PlanSharingSheet.show(context, plan);
  }

  Future<void> _archivePlan(Plan plan) async {
    final result =
        await ref.read(planningProvider.notifier).archivePlan(plan.id);
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan "${plan.title}" archived')),
      );
      context.pop();
    }
  }

  void _confirmDeletePlan(Plan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: Text(
          'Are you sure you want to delete "${plan.title}"? '
          'This will also delete all tasks and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await ref.read(planningProvider.notifier).deletePlan(plan.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Plan "${plan.title}" deleted')),
                );
                context.pop();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, Plan plan) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    TaskPriority selectedPriority = TaskPriority.medium;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.listPlus),
              SizedBox(width: 12),
              Text('Add Task'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    prefixIcon: Icon(LucideIcons.type),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(LucideIcons.alignLeft),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Priority',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<TaskPriority>(
                  segments: const [
                    ButtonSegment(
                      value: TaskPriority.low,
                      label: Text('Low'),
                    ),
                    ButtonSegment(
                      value: TaskPriority.medium,
                      label: Text('Medium'),
                    ),
                    ButtonSegment(
                      value: TaskPriority.high,
                      label: Text('High'),
                    ),
                    ButtonSegment(
                      value: TaskPriority.critical,
                      label: Text('Critical'),
                    ),
                  ],
                  selected: {selectedPriority},
                  onSelectionChanged: (selected) {
                    setDialogState(() {
                      selectedPriority = selected.first;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await ref.read(planningProvider.notifier).createTask(
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      priority: selectedPriority,
                    );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress indicator widget showing completion percentage
/// Implements Requirement 8.1
class _ProgressIndicator extends StatelessWidget {
  final int percentage;

  const _ProgressIndicator({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(
                _getProgressColor(percentage),
              ),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$percentage%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(int percentage) {
    if (percentage >= 100) return Colors.greenAccent;
    if (percentage >= 75) return Colors.lightGreenAccent;
    if (percentage >= 50) return Colors.amberAccent;
    if (percentage >= 25) return Colors.orangeAccent;
    return Colors.white;
  }
}

/// Connection status indicator widget
class _ConnectionIndicator extends StatelessWidget {
  final bool isConnected;

  const _ConnectionIndicator({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isConnected ? 'Real-time sync active' : 'Offline',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isConnected ? LucideIcons.wifi : LucideIcons.wifiOff,
          size: 16,
          color: isConnected ? Colors.greenAccent : Colors.white70,
        ),
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.5),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              title,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}

/// Tasks section widget
/// Implements Requirement 1.3: Display tasks
/// Uses TaskListWidget from task_list_widget.dart for full task management
class _TasksSection extends StatelessWidget {
  final Plan plan;

  const _TasksSection({required this.plan});

  @override
  Widget build(BuildContext context) {
    return TaskListWidget(
      tasks: plan.tasks,
      showEmptyState: true,
      emptyTitle: 'No Tasks Yet',
      emptySubtitle: 'Add tasks to start tracking your progress',
    );
  }
}

/// Requirements section widget
/// Implements Requirement 4.1: Show requirements section
class _RequirementsSection extends StatelessWidget {
  final List<Requirement> requirements;

  const _RequirementsSection({required this.requirements});

  @override
  Widget build(BuildContext context) {
    if (requirements.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.fileText,
        title: 'No Requirements Yet',
        subtitle: 'Requirements will appear here when added',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requirements.length,
      itemBuilder: (context, index) {
        final requirement = requirements[index];
        return _RequirementCard(requirement: requirement)
            .animate()
            .fadeIn(delay: Duration(milliseconds: index * 50));
      },
    );
  }
}

/// Requirement card widget
class _RequirementCard extends StatelessWidget {
  final Requirement requirement;

  const _RequirementCard({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.fileCheck,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    requirement.title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _EarsPatternChip(pattern: requirement.earsPattern),
              ],
            ),
            if (requirement.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                requirement.description,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
            if (requirement.acceptanceCriteria.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Acceptance Criteria',
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              ...requirement.acceptanceCriteria.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// EARS pattern chip widget
class _EarsPatternChip extends StatelessWidget {
  final EarsPattern pattern;

  const _EarsPatternChip({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (pattern) {
      EarsPattern.ubiquitous => (Colors.blue, 'Ubiquitous'),
      EarsPattern.event => (Colors.green, 'Event'),
      EarsPattern.state => (Colors.purple, 'State'),
      EarsPattern.unwanted => (Colors.orange, 'Unwanted'),
      EarsPattern.optional => (Colors.teal, 'Optional'),
      EarsPattern.complex => (Colors.indigo, 'Complex'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Design notes section widget
/// Implements Requirement 4.1: Show design notes section
class _DesignNotesSection extends StatelessWidget {
  final List<DesignNote> designNotes;

  const _DesignNotesSection({required this.designNotes});

  @override
  Widget build(BuildContext context) {
    if (designNotes.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.lightbulb,
        title: 'No Design Notes Yet',
        subtitle: 'Design notes will appear here when added',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: designNotes.length,
      itemBuilder: (context, index) {
        final note = designNotes[index];
        return _DesignNoteCard(note: note)
            .animate()
            .fadeIn(delay: Duration(milliseconds: index * 50));
      },
    );
  }
}

/// Design note card widget
class _DesignNoteCard extends StatelessWidget {
  final DesignNote note;

  const _DesignNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.lightbulb,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Design Note',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatDate(note.createdAt),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note.content,
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            if (note.requirementIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: note.requirementIds.map((id) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.link,
                          size: 12,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Req ${id.substring(0, 8)}...',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
