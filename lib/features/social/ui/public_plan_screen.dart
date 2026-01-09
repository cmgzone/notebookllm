import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../social_sharing_provider.dart';
import '../../../core/api/api_service.dart';

/// Screen to view a public plan with its requirements, tasks, and design notes
/// Users can view plan details and fork the plan to their account
class PublicPlanScreen extends ConsumerStatefulWidget {
  final String planId;

  const PublicPlanScreen({super.key, required this.planId});

  @override
  ConsumerState<PublicPlanScreen> createState() => _PublicPlanScreenState();
}

class _PublicPlanScreenState extends ConsumerState<PublicPlanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isForking = false;
  String? _error;
  Map<String, dynamic>? _plan;
  List<dynamic> _requirements = [];
  List<dynamic> _tasks = [];
  List<dynamic> _designNotes = [];
  Map<String, dynamic>? _owner;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPlanDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlanDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response =
          await api.get('/social-sharing/public/plans/${widget.planId}');

      if (response['success'] == true) {
        setState(() {
          _plan = response['plan'];
          _requirements = response['requirements'] ?? [];
          _tasks = response['tasks'] ?? [];
          _designNotes = response['designNotes'] ?? [];
          _owner = response['owner'];
          _isLoading = false;
        });

        // Record view
        ref
            .read(socialSharingServiceProvider)
            .recordView('plan', widget.planId);
      } else {
        setState(() {
          _error = 'Plan not found or not public';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _forkPlan() async {
    setState(() => _isForking = true);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/social-sharing/fork/plan/${widget.planId}',
        {
          'includeRequirements': true,
          'includeTasks': true,
          'includeDesignNotes': true,
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Plan forked! ${response['requirementsCopied']} requirements, '
                '${response['tasksCopied']} tasks copied.',
              ),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  context.push('/planning/${response['plan']['id']}');
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fork: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isForking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error ?? 'Plan not found',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final plan = _plan!;
    final title = plan['title'] ?? 'Untitled';
    final description = plan['description'];
    final status = plan['status'] ?? 'draft';
    final taskCount = int.tryParse(plan['task_count']?.toString() ?? '0') ?? 0;
    final completedTaskCount =
        int.tryParse(plan['completed_task_count']?.toString() ?? '0') ?? 0;
    final requirementCount =
        int.tryParse(plan['requirement_count']?.toString() ?? '0') ?? 0;
    final viewCount = plan['view_count'] ?? 0;
    final likeCount = int.tryParse(plan['like_count']?.toString() ?? '0') ?? 0;
    final completionPercentage =
        taskCount > 0 ? (completedTaskCount / taskCount * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share link functionality
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
            Tab(text: 'Requirements', icon: Icon(Icons.checklist)),
            Tab(text: 'Tasks', icon: Icon(Icons.task_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          _buildOverviewTab(
            theme,
            plan,
            title,
            description,
            status,
            taskCount,
            completedTaskCount,
            requirementCount,
            viewCount,
            likeCount,
            completionPercentage,
          ),
          // Requirements Tab
          _buildRequirementsTab(theme),
          // Tasks Tab
          _buildTasksTab(theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(discoverProvider.notifier).likePlan(widget.planId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Liked!')),
                    );
                  },
                  icon: Icon(
                    plan['user_liked'] == true
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: plan['user_liked'] == true ? Colors.red : null,
                  ),
                  label: const Text('Like'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isForking ? null : _forkPlan,
                  icon: _isForking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.fork_right),
                  label: Text(_isForking ? 'Forking...' : 'Fork to My Plans'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    ThemeData theme,
    Map<String, dynamic> plan,
    String title,
    String? description,
    String status,
    int taskCount,
    int completedTaskCount,
    int requirementCount,
    int viewCount,
    int likeCount,
    int completionPercentage,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owner info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: _owner?['avatarUrl'] != null
                        ? NetworkImage(_owner!['avatarUrl'])
                        : null,
                    child: _owner?['avatarUrl'] == null
                        ? Text((_owner?['username'] ?? '?')[0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _owner?['username'] ?? 'Unknown',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Created ${timeago.format(DateTime.parse(plan['created_at']))}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          if (description != null && description.isNotEmpty) ...[
            Text('Description',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(description),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Progress
          Text('Progress',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$completedTaskCount of $taskCount tasks completed'),
                      Text('$completionPercentage%',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: completionPercentage / 100,
                    backgroundColor: Colors.grey[200],
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Text('Statistics',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.checklist,
                  value: requirementCount.toString(),
                  label: 'Requirements',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.task_alt,
                  value: taskCount.toString(),
                  label: 'Tasks',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.visibility,
                  value: viewCount.toString(),
                  label: 'Views',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite,
                  value: likeCount.toString(),
                  label: 'Likes',
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Design Notes preview
          if (_designNotes.isNotEmpty) ...[
            Text('Design Notes (${_designNotes.length})',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _designNotes.length > 3 ? 3 : _designNotes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final note = _designNotes[index];
                  final content = note['content'] ?? '';
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      content.length > 100
                          ? '${content.substring(0, 100)}...'
                          : content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      timeago.format(DateTime.parse(note['created_at'])),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementsTab(ThemeData theme) {
    if (_requirements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No requirements defined',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requirements.length,
      itemBuilder: (context, index) {
        final req = _requirements[index];
        return _RequirementCard(requirement: req);
      },
    );
  }

  Widget _buildTasksTab(ThemeData theme) {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No tasks defined', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    // Build hierarchical task list
    final rootTasks = _tasks.where((t) => t['parent_task_id'] == null).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rootTasks.length,
      itemBuilder: (context, index) {
        final task = rootTasks[index];
        final subtasks =
            _tasks.where((t) => t['parent_task_id'] == task['id']).toList();
        return _TaskCard(task: task, subtasks: subtasks);
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case 'active':
        color = Colors.blue;
        icon = Icons.play_circle_outline;
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'archived':
        color = Colors.grey;
        icon = Icons.archive_outlined;
        break;
      default:
        color = Colors.orange;
        icon = Icons.edit_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  final Map<String, dynamic> requirement;

  const _RequirementCard({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = requirement['title'] ?? 'Untitled';
    final description = requirement['description'];
    final earsPattern = requirement['ears_pattern'];
    final acceptanceCriteria = requirement['acceptance_criteria'] as List?;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    earsPattern?.toUpperCase() ?? 'REQ',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: TextStyle(color: Colors.grey[700])),
            ],
            if (acceptanceCriteria != null &&
                acceptanceCriteria.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Acceptance Criteria:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600])),
              const SizedBox(height: 4),
              ...acceptanceCriteria.map((criteria) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            criteria.toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final List<dynamic> subtasks;

  const _TaskCard({required this.task, required this.subtasks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = task['title'] ?? 'Untitled';
    final description = task['description'];
    final status = task['status'] ?? 'not_started';
    final priority = task['priority'] ?? 'medium';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TaskStatusIcon(status: status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: status == 'completed'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    _PriorityBadge(priority: priority),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (subtasks.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 16, 8),
              child: Column(
                children: subtasks.map((subtask) {
                  final subStatus = subtask['status'] ?? 'not_started';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _TaskStatusIcon(status: subStatus, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subtask['title'] ?? 'Subtask',
                            style: TextStyle(
                              fontSize: 13,
                              decoration: subStatus == 'completed'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskStatusIcon extends StatelessWidget {
  final String status;
  final double size;

  const _TaskStatusIcon({required this.status, this.size = 24});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case 'completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'in_progress':
        icon = Icons.play_circle_filled;
        color = Colors.blue;
        break;
      case 'blocked':
        icon = Icons.block;
        color = Colors.red;
        break;
      case 'paused':
        icon = Icons.pause_circle_filled;
        color = Colors.orange;
        break;
      default:
        icon = Icons.radio_button_unchecked;
        color = Colors.grey;
    }

    return Icon(icon, size: size, color: color);
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case 'critical':
        color = Colors.red;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'medium':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
