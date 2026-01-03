import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'github_provider.dart';
import 'github_repos_screen.dart';

/// Screen for connecting GitHub account
class GitHubConnectScreen extends ConsumerStatefulWidget {
  const GitHubConnectScreen({super.key});

  @override
  ConsumerState<GitHubConnectScreen> createState() =>
      _GitHubConnectScreenState();
}

class _GitHubConnectScreenState extends ConsumerState<GitHubConnectScreen> {
  final _tokenController = TextEditingController();
  bool _showToken = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(githubProvider.notifier).checkStatus();
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connectWithToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Personal Access Token')),
      );
      return;
    }

    setState(() => _isConnecting = true);

    final success =
        await ref.read(githubProvider.notifier).connectWithToken(token);

    setState(() => _isConnecting = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GitHubReposScreen()),
      );
    } else if (mounted) {
      final error = ref.read(githubProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Connection failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(githubProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect GitHub'),
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && !_isConnecting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.isConnected) {
            return _buildConnectedView(state);
          }

          return _buildConnectView();
        },
      ),
    );
  }

  Widget _buildConnectedView(GitHubState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: state.connection?.avatarUrl != null
                    ? NetworkImage(state.connection!.avatarUrl!)
                    : null,
                child: state.connection?.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(state.connection?.username ?? 'Connected'),
              subtitle: Text(state.connection?.email ?? 'GitHub Account'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GitHubReposScreen()),
              );
            },
            icon: const Icon(Icons.folder),
            label: const Text('Browse Repositories'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Disconnect GitHub?'),
                  content: const Text(
                    'This will remove your GitHub connection. You can reconnect anytime.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                await ref.read(githubProvider.notifier).disconnect();
              }
            },
            icon: const Icon(Icons.link_off),
            label: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.code,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connect GitHub',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Access your repositories and let AI analyze your code',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Token input
          const Text(
            'Personal Access Token',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenController,
            obscureText: !_showToken,
            decoration: InputDecoration(
              hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon:
                    Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showToken = !_showToken),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a token at GitHub → Settings → Developer settings → Personal access tokens',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Required scopes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Required Scopes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildScopeItem(
                      'repo', 'Full control of private repositories'),
                  _buildScopeItem('read:user', 'Read user profile data'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Connect button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isConnecting ? null : _connectWithToken,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(_isConnecting ? 'Connecting...' : 'Connect GitHub'),
            ),
          ),
          const SizedBox(height: 32),

          // Features
          const Text(
            'What you can do',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.folder_open,
            'Browse Repositories',
            'Access all your public and private repos',
          ),
          _buildFeatureItem(
            Icons.search,
            'Search Code',
            'Find code across your repositories',
          ),
          _buildFeatureItem(
            Icons.psychology,
            'AI Analysis',
            'Get intelligent insights about your codebase',
          ),
          _buildFeatureItem(
            Icons.add_circle,
            'Import as Source',
            'Add GitHub files to your notebooks',
          ),
        ],
      ),
    );
  }

  Widget _buildScopeItem(String scope, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            scope,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
