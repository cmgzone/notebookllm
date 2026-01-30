import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'services/gitu_agents_service.dart';
import '../../theme/app_theme.dart';

class AgentDetailScreen extends ConsumerWidget {
  final String agentId;

  const AgentDetailScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentAsync = ref.watch(gituAgentDetailProvider(agentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(gituAgentDetailProvider(agentId)),
          ),
        ],
      ),
      body: agentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (agent) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(agent),
              const SizedBox(height: 24),
              _buildSectionTitle('Task'),
              _buildCard(Text(agent.task, style: const TextStyle(fontSize: 16))),
              const SizedBox(height: 24),
              _buildSectionTitle('Status'),
               _buildCard(Row(
                 children: [
                   _buildStatusIcon(agent.status),
                   const SizedBox(width: 8),
                   Text(agent.status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                 ],
               )),
              const SizedBox(height: 24),
              if (agent.status == 'completed' && agent.result != null) ...[
                 _buildSectionTitle('Result'),
                 _buildCard(MarkdownBody(data: agent.result?['output'] ?? 'No output')),
              ] else if (agent.memory.isNotEmpty) ...[
                 _buildSectionTitle('Thought Process'),
                 _buildMemoryLog(agent.memory),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(GituAgent agent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Agent ID: ${agent.id.substring(0, 8)}', style: const TextStyle(color: Colors.grey)),
        Text('Created: ${agent.createdAt.toLocal()}', style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
    );
  }

  Widget _buildCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: child,
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

  Widget _buildMemoryLog(Map<String, dynamic> memory) {
      // Basic rendering of memory history if available
      if (memory['history'] is List) {
          final history = memory['history'] as List;
          return Column(
              children: history.map<Widget>((entry) {
                  final role = entry['role'] ?? 'unknown';
                  final content = entry['content'] ?? '';
                  return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: role == 'assistant' ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              MarkdownBody(data: content),
                          ],
                      ),
                  );
              }).toList(),
          );
      }
      return _buildCard(Text(memory.toString()));
  }
}
