import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../social_provider.dart';
import '../models/friend.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<UserSearchResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(friendsProvider.notifier).loadFriends();
      ref.read(friendsProvider.notifier).loadRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results =
          await ref.read(friendsProvider.notifier).searchUsers(query);
      setState(() => _searchResults = results);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Friends (${state.friends.length})'),
            Tab(text: 'Requests (${state.receivedRequests.length})'),
            const Tab(text: 'Find'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(state),
          _buildRequestsList(state),
          _buildSearchTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsList(FriendsState state) {
    if (state.isLoading && state.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No friends yet', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: const Text('Find friends'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(friendsProvider.notifier).loadFriends(),
      child: ListView.builder(
        itemCount: state.friends.length,
        itemBuilder: (context, index) {
          final friend = state.friends[index];
          return _FriendTile(
            friend: friend,
            onRemove: () => _confirmRemoveFriend(friend),
            onMessage: () {
              context.push(
                '/social/chat/${friend.id}',
                extra: friend.username,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestsList(FriendsState state) {
    final allRequests = [
      ...state.receivedRequests.map((r) => _RequestItem(r, true)),
      ...state.sentRequests.map((r) => _RequestItem(r, false)),
    ];

    if (allRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No pending requests',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(friendsProvider.notifier).loadRequests(),
      child: ListView.builder(
        itemCount: allRequests.length,
        itemBuilder: (context, index) {
          final item = allRequests[index];
          return _FriendRequestTile(
            request: item.request,
            isReceived: item.isReceived,
            onAccept: () => ref
                .read(friendsProvider.notifier)
                .acceptRequest(item.request.id),
            onDecline: () => ref
                .read(friendsProvider.notifier)
                .declineRequest(item.request.id),
          );
        },
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by username or email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _searchUsers,
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'Search for users to add as friends'
                        : 'No users found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (listContext, index) {
                    final user = _searchResults[index];
                    return _UserSearchTile(
                      user: user,
                      onAdd: () async {
                        await ref
                            .read(friendsProvider.notifier)
                            .sendFriendRequest(user.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Friend request sent to ${user.username}')),
                        );
                        setState(() => _searchResults.remove(user));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmRemoveFriend(Friend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
            'Are you sure you want to remove ${friend.username} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(friendsProvider.notifier).removeFriend(friend.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _RequestItem {
  final FriendRequest request;
  final bool isReceived;
  _RequestItem(this.request, this.isReceived);
}

class _FriendTile extends StatelessWidget {
  final Friend friend;
  final VoidCallback onRemove;
  final VoidCallback onMessage;

  const _FriendTile({
    required this.friend,
    required this.onRemove,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
        child: friend.avatarUrl == null
            ? Text(friend.username[0].toUpperCase())
            : null,
      ),
      title: Text(friend.username),
      subtitle: Text(friend.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: onMessage,
            tooltip: 'Send message',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'remove', child: Text('Remove friend')),
            ],
            onSelected: (value) {
              if (value == 'remove') onRemove();
            },
          ),
        ],
      ),
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  final FriendRequest request;
  final bool isReceived;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FriendRequestTile({
    required this.request,
    required this.isReceived,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: request.fromAvatarUrl != null
            ? NetworkImage(request.fromAvatarUrl!)
            : null,
        child: request.fromAvatarUrl == null
            ? Text(request.fromUsername[0].toUpperCase())
            : null,
      ),
      title: Text(request.fromUsername),
      subtitle: Text(isReceived ? 'Wants to be your friend' : 'Request sent'),
      trailing: isReceived
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: onAccept,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: onDecline,
                ),
              ],
            )
          : const Icon(Icons.hourglass_empty, color: Colors.orange),
    );
  }
}

class _UserSearchTile extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback onAdd;

  const _UserSearchTile({required this.user, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
        child: user.avatarUrl == null
            ? Text(user.username[0].toUpperCase())
            : null,
      ),
      title: Text(user.username),
      subtitle: Text(user.email),
      trailing: IconButton(
        icon: const Icon(Icons.person_add),
        onPressed: onAdd,
      ),
    );
  }
}
