import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';

class GituAnalyticsScreen extends ConsumerStatefulWidget {
  const GituAnalyticsScreen({super.key});

  @override
  ConsumerState<GituAnalyticsScreen> createState() => _GituAnalyticsScreenState();
}

class _GituAnalyticsScreenState extends ConsumerState<GituAnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.getGituAnalytics();
      setState(() {
        _data = response;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gitu Analytics')),
        body: Center(child: Text('Failed to load analytics: $_error')),
      );
    }

    final analytics = (_data?['analytics'] as Map<String, dynamic>?) ?? {};
    final messages = (analytics['messages'] as Map<String, dynamic>?) ?? {};
    final usage = (analytics['usage'] as Map<String, dynamic>?) ?? {};
    final tasks = (analytics['tasks'] as Map<String, dynamic>?) ?? {};
    final memories = (analytics['memories'] as Map<String, dynamic>?) ?? {};

    final byPlatform = (messages['byPlatform'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final byModel = (usage['byModel'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(title: const Text('Gitu Analytics')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Messages',
                    value: '${messages['total'] ?? 0}',
                    icon: Icons.message,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Tokens',
                    value: '${usage['tokens'] ?? 0}',
                    icon: Icons.bolt,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Cost (USD)',
                    value: '${usage['cost'] ?? 0}',
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Memories',
                    value: '${memories['total'] ?? 0}',
                    icon: Icons.memory,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Messages by Platform',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (byPlatform.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No message data yet'),
                ),
              )
            else
              ...byPlatform.map((row) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text('${row['platform'] ?? 'unknown'}'),
                      trailing: Text('${row['count'] ?? 0}'),
                    ),
                  )),
            const SizedBox(height: 24),
            Text('Top Models',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (byModel.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No usage data yet'),
                ),
              )
            else
              ...byModel.map((row) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome),
                      title: Text('${row['model'] ?? 'unknown'}'),
                      subtitle: Text(
                          '${row['tokens'] ?? 0} tokens • ${row['count'] ?? 0} calls'),
                      trailing: Text('\$${row['cost'] ?? 0}'),
                    ),
                  )),
            const SizedBox(height: 24),
            Text('Scheduled Tasks',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('Total: ${tasks['total'] ?? 0}'),
                subtitle: Text('Enabled: ${tasks['enabled'] ?? 0}'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.task_alt),
                title: Text(
                    'Executions: ${tasks['executions']?['total'] ?? 0}'),
                subtitle: Text(
                    'Success: ${tasks['executions']?['success'] ?? 0} • Failed: ${tasks['executions']?['failed'] ?? 0}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

