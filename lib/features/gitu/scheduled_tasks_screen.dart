import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import 'models/scheduled_task.dart';
import 'services/scheduled_task_service.dart';

class GituScheduledTasksScreen extends ConsumerWidget {
  const GituScheduledTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(scheduledTasksProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
        ),
        title: const Text(
          'Scheduled Tasks',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(scheduledTasksProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.calendarClock,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No scheduled tasks yet'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateTaskDialog(context, ref),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Create Task'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(scheduledTasksProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _TaskTile(task: tasks[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTaskDialog(context, ref),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  void _showCreateTaskDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _CreateTaskDialog(),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final ScheduledTask task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lastRunStatus = task.lastRunStatus;
    Color statusColor = Colors.grey;
    if (lastRunStatus == 'success') statusColor = Colors.green;
    if (lastRunStatus == 'failed') statusColor = Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Action: ${task.action}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: task.enabled,
                  onChanged: (val) async {
                    await ref
                        .read(scheduledTaskServiceProvider)
                        .updateTask(task.id, {'enabled': val});
                    ref.invalidate(scheduledTasksProvider);
                  },
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      task.cron,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                if (task.lastRunAt != null)
                  Row(
                    children: [
                      Icon(LucideIcons.activity, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo(task.lastRunAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showHistorySheet(context, ref, task),
                  icon: const Icon(LucideIcons.history, size: 18),
                  label: const Text('History'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _triggerTask(context, ref, task),
                  icon: const Icon(LucideIcons.play, size: 18),
                  label: const Text('Run Now'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _confirmDelete(context, ref, task);
                    } else if (value == 'edit') {
                      showDialog(
                        context: context,
                        builder: (context) => _CreateTaskDialog(task: task),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(LucideIcons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _triggerTask(
      BuildContext context, WidgetRef ref, ScheduledTask task) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Triggering task...')),
      );
      await ref.read(scheduledTaskServiceProvider).triggerTask(task.id);
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Task triggered. Check history for results.')),
      );
      ref.invalidate(scheduledTasksProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to trigger task: $e')),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ScheduledTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(scheduledTaskServiceProvider).deleteTask(task.id);
              ref.invalidate(scheduledTasksProvider);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showHistorySheet(
      BuildContext context, WidgetRef ref, ScheduledTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExecutionHistorySheet(task: task),
    );
  }
}

class _CreateTaskDialog extends ConsumerStatefulWidget {
  final ScheduledTask? task;

  const _CreateTaskDialog({this.task});

  @override
  ConsumerState<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<_CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _cronController;
  String _action = 'memories.detectContradictions';
  bool _isLoading = false;

  final List<String> _availableActions = [
    'memories.detectContradictions',
    'memories.expireUnverified',
    'sessions.cleanupOldSessions',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _cronController =
        TextEditingController(text: widget.task?.cron ?? '0 * * * *');
    if (widget.task != null) {
      _action = widget.task!.action;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cronController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Task' : 'Create Task'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Task Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _action,
                decoration: const InputDecoration(
                  labelText: 'Action',
                  border: OutlineInputBorder(),
                ),
                items: _availableActions.map((a) {
                  return DropdownMenuItem(
                    value: a,
                    child: Text(a.split('.').last, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _action = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cronController,
                decoration: const InputDecoration(
                  labelText: 'Cron Expression',
                  hintText: '* * * * *',
                  border: OutlineInputBorder(),
                  helperText: 'min hour day month weekday',
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Cron is required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(scheduledTaskServiceProvider);
      final data = {
        'name': _nameController.text,
        'action': _action,
        'cron': _cronController.text,
        'enabled': true,
      };

      if (widget.task != null) {
        await service.updateTask(widget.task!.id, data);
      } else {
        await service.createTask(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(scheduledTasksProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _ExecutionHistorySheet extends ConsumerStatefulWidget {
  final ScheduledTask task;

  const _ExecutionHistorySheet({required this.task});

  @override
  ConsumerState<_ExecutionHistorySheet> createState() =>
      _ExecutionHistorySheetState();
}

class _ExecutionHistorySheetState
    extends ConsumerState<_ExecutionHistorySheet> {
  late Future<List<TaskExecution>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ref
        .read(scheduledTaskServiceProvider)
        .getExecutions(widget.task.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Execution History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<TaskExecution>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const Center(child: Text('No execution history found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final exec = history[index];
                    return ListTile(
                      leading: Icon(
                        exec.success
                            ? LucideIcons.checkCircle
                            : LucideIcons.xCircle,
                        color: exec.success ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        DateFormat('MMM d, y HH:mm:ss')
                            .format(exec.executedAt.toLocal()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (exec.error != null)
                            Text(
                              'Error: ${exec.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          Text(
                            'Duration: ${exec.duration ?? 0} ms',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
