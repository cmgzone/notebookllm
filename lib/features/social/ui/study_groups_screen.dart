import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../social_provider.dart';
import '../models/study_group.dart';
import 'study_group_detail_screen.dart';

class StudyGroupsScreen extends ConsumerStatefulWidget {
  const StudyGroupsScreen({super.key});

  @override
  ConsumerState<StudyGroupsScreen> createState() => _StudyGroupsScreenState();
}

class _StudyGroupsScreenState extends ConsumerState<StudyGroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StudyGroup> _publicGroups = [];
  bool _isLoadingPublic = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(studyGroupsProvider.notifier).loadGroups();
      ref.read(studyGroupsProvider.notifier).loadInvitations();
      _loadPublicGroups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPublicGroups({String? search}) async {
    setState(() => _isLoadingPublic = true);
    try {
      final groups = await ref
          .read(studyGroupsProvider.notifier)
          .discoverPublicGroups(search: search);
      setState(() => _publicGroups = groups);
    } finally {
      setState(() => _isLoadingPublic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Groups'),
        actions: [
          if (state.invitations.isNotEmpty)
            Badge(
              label: Text('${state.invitations.length}'),
              child: IconButton(
                icon: const Icon(Icons.mail),
                onPressed: () => _showInvitations(state.invitations),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Groups'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyGroupsTab(state),
          _buildDiscoverTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
    );
  }

  Widget _buildMyGroupsTab(StudyGroupsState state) {
    if (state.isLoading && state.groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.groups.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(studyGroupsProvider.notifier).loadGroups(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.groups.length,
        itemBuilder: (context, index) {
          final group = state.groups[index];
          return _GroupCard(
            group: group,
            onTap: () => _openGroup(group),
          );
        },
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search public groups...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadPublicGroups();
                      },
                    )
                  : null,
            ),
            onSubmitted: (value) => _loadPublicGroups(search: value),
          ),
        ),
        Expanded(
          child: _isLoadingPublic
              ? const Center(child: CircularProgressIndicator())
              : _publicGroups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public_off,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No public groups found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadPublicGroups(
                          search: _searchController.text.isEmpty
                              ? null
                              : _searchController.text),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _publicGroups.length,
                        itemBuilder: (context, index) {
                          final group = _publicGroups[index];
                          return _PublicGroupCard(
                            group: group,
                            onJoin: () => _joinGroup(group),
                            onTap: () => _openGroup(group),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No study groups yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a group or discover public groups',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _tabController.animateTo(1),
            icon: const Icon(Icons.public),
            label: const Text('Discover Groups'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGroup(StudyGroup group) async {
    try {
      await ref.read(studyGroupsProvider.notifier).joinPublicGroup(group.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${group.name}!')),
        );
        _loadPublicGroups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    }
  }

  void _openGroup(StudyGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyGroupDetailScreen(groupId: group.id),
      ),
    );
  }

  void _createGroup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CreateGroupSheet(),
    );
  }

  void _showInvitations(List<GroupInvitation> invitations) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _InvitationsSheet(invitations: invitations),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final StudyGroup group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(group.icon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (group.isOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Owner',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (group.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} members',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        if (group.isPublic) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.public, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'Public',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedIcon = '📚';
  bool _isPublic = false;
  bool _isLoading = false;

  final _icons = ['📚', '🎓', '💡', '🔬', '📐', '🎨', '💻', '🌍', '📖', '✏️'];

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
          Text('Create Study Group',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Text('Icon', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _icons.map((icon) {
              final isSelected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 24))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Public Group'),
            subtitle: const Text('Anyone can find and join'),
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create Group'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(studyGroupsProvider.notifier).createGroup(
            name: _nameController.text.trim(),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            icon: _selectedIcon,
            isPublic: _isPublic,
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _InvitationsSheet extends ConsumerWidget {
  final List<GroupInvitation> invitations;

  const _InvitationsSheet({required this.invitations});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Group Invitations',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            final inv = invitations[index];
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(inv.groupIcon)),
              ),
              title: Text(inv.groupName),
              subtitle: Text('Invited by ${inv.invitedByUsername}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      ref
                          .read(studyGroupsProvider.notifier)
                          .acceptInvitation(inv.id);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PublicGroupCard extends StatelessWidget {
  final StudyGroup group;
  final VoidCallback onJoin;
  final VoidCallback onTap;

  const _PublicGroupCard({
    required this.group,
    required this.onJoin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMember =
        group.role != GroupRole.member || group.isOwner || group.isAdmin;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isMember ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(group.icon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (group.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} members',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (group.role != GroupRole.member)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Joined',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: onJoin,
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Join'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
