import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../models/study_group.dart';
import '../social_provider.dart';

class StudyGroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const StudyGroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<StudyGroupDetailScreen> createState() =>
      _StudyGroupDetailScreenState();
}

class _StudyGroupDetailScreenState
    extends ConsumerState<StudyGroupDetailScreen> {
  StudyGroup? _group;
  List<GroupMember> _members = [];
  List<StudySession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final groupRes = await api.get('/social/groups/${widget.groupId}');
      final membersRes =
          await api.get('/social/groups/${widget.groupId}/members');
      final sessionsRes =
          await api.get('/social/groups/${widget.groupId}/sessions');

      setState(() {
        _group = StudyGroup.fromJson(groupRes['group']);
        _members = (membersRes['members'] as List)
            .map((m) => GroupMember.fromJson(m))
            .toList();
        _sessions = (sessionsRes['sessions'] as List)
            .map((s) => StudySession.fromJson(s))
            .toList();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Group not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_group!.name),
        actions: [
          if (_group!.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettings,
            ),
          PopupMenuButton(
            itemBuilder: (context) => [
              if (!_group!.isOwner)
                const PopupMenuItem(value: 'leave', child: Text('Leave Group')),
              if (_group!.isOwner)
                const PopupMenuItem(
                    value: 'delete', child: Text('Delete Group')),
            ],
            onSelected: (value) {
              if (value == 'leave') _leaveGroup();
              if (value == 'delete') _deleteGroup();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroup,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(theme),
            const SizedBox(height: 24),
            _buildSessionsSection(theme),
            const SizedBox(height: 24),
            _buildMembersSection(theme),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scheduleSession,
        icon: const Icon(Icons.event),
        label: const Text('Schedule Session'),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(_group!.icon, style: const TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 12),
            Text(_group!.name, style: theme.textTheme.headlineSmall),
            if (_group!.description != null) ...[
              const SizedBox(height: 8),
              Text(_group!.description!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatChip(
                    icon: Icons.people, label: '${_members.length} members'),
                const SizedBox(width: 12),
                _StatChip(
                    icon: Icons.event, label: '${_sessions.length} sessions'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming Sessions', style: theme.textTheme.titleMedium),
            TextButton(
              onPressed: _scheduleSession,
              child: const Text('+ Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_sessions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('No upcoming sessions',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          )
        else
          ...(_sessions
              .take(3)
              .map((session) => _SessionCard(session: session))),
      ],
    );
  }

  Widget _buildMembersSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Members', style: theme.textTheme.titleMedium),
            if (_group!.isAdmin)
              TextButton(
                onPressed: _inviteMember,
                child: const Text('+ Invite'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: _members.map((member) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: member.avatarUrl != null
                      ? NetworkImage(member.avatarUrl!)
                      : null,
                  child: member.avatarUrl == null
                      ? Text(member.username[0].toUpperCase())
                      : null,
                ),
                title: Text(member.username),
                subtitle: Text(member.role),
                trailing: member.role == 'owner'
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Owner',
                          style: TextStyle(
                              fontSize: 12, color: theme.colorScheme.onPrimary),
                        ),
                      )
                    : null,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _scheduleSession() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ScheduleSessionSheet(
        groupId: widget.groupId,
        onCreated: _loadGroup,
      ),
    );
  }

  void _inviteMember() {
    // Feature coming soon - will show friend picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite feature coming soon')),
    );
  }

  void _showSettings() {
    // Feature coming soon - will show group settings
  }

  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref
                  .read(studyGroupsProvider.notifier)
                  .leaveGroup(widget.groupId);
              if (!mounted) return;
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _deleteGroup() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
            'This will permanently delete the group and all its data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref
                  .read(studyGroupsProvider.notifier)
                  .deleteGroup(widget.groupId);
              if (!mounted) return;
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final StudySession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text(session.title),
        subtitle: Text(_formatDate(session.scheduledAt)),
        trailing: Text('${session.durationMinutes} min'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ScheduleSessionSheet extends ConsumerStatefulWidget {
  final String groupId;
  final VoidCallback onCreated;

  const _ScheduleSessionSheet({required this.groupId, required this.onCreated});

  @override
  ConsumerState<_ScheduleSessionSheet> createState() =>
      _ScheduleSessionSheetState();
}

class _ScheduleSessionSheetState extends ConsumerState<_ScheduleSessionSheet> {
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  int _duration = 60;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Schedule Study Session',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
                labelText: 'Session Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_selectedTime.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _duration,
            decoration: const InputDecoration(
                labelText: 'Duration', border: OutlineInputBorder()),
            items: [30, 45, 60, 90, 120]
                .map((d) =>
                    DropdownMenuItem(value: d, child: Text('$d minutes')))
                .toList(),
            onChanged: (v) => setState(() => _duration = v!),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _createSession,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Schedule'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time =
        await showTimePicker(context: context, initialTime: _selectedTime);
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _createSession() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      await ref.read(studyGroupsProvider.notifier).createSession(
            groupId: widget.groupId,
            title: _titleController.text.trim(),
            scheduledAt: scheduledAt,
            durationMinutes: _duration,
          );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
