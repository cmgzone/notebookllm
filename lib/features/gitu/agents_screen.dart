import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'services/gitu_agents_service.dart';
import '../../theme/app_theme.dart';

class AgentsScreen extends ConsumerWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(gituAgentsProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
        ),
        title: const Text('Autonomous Agents',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(gituAgentsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSpawnDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: agentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (agents) {
          if (agents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.psychology, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No active agents'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _showSpawnDialog(context, ref),
                    child: const Text('Spawn Agent'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final agent = agents[index];
              return Card(
                child: ListTile(
                  leading: _buildStatusIcon(agent.status),
                  title: Text(agent.task, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Status: ${agent.status} • ID: ${agent.id.substring(0, 8)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.pushNamed('gitu-agent-detail', pathParameters: {'id': agent.id});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'active':
        return const Icon(Icons.autorenew, color: Colors.green);
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.blue);
      case 'failed':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
    }
  }

  void _showSpawnDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spawn New Agent'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Task Description',
            hintText: 'e.g., Research quantum computing trends',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                Navigator.pop(context);
                await ref.read(gituAgentsServiceProvider).spawnAgent(controller.text);
                ref.refresh(gituAgentsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Agent spawned successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Spawn'),
          ),
        ],
      ),
    );
  }
}
