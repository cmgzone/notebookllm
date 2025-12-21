import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_service.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  final String? notebookId;

  const AnalyticsScreen({super.key, this.notebookId});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _topics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);

    final service = ref.read(analyticsServiceProvider);
    final stats = await service.getQueryStats(notebookId: widget.notebookId);
    final topics = await service.getTopTopics(notebookId: widget.notebookId);

    if (mounted) {
      setState(() {
        _stats = stats;
        _topics = topics;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Queries',
                          value: '${_stats?['totalQueries'] ?? 0}',
                          icon: Icons.question_answer,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Avg Response',
                          value: '${_stats?['avgResponseTime'] ?? 0}ms',
                          icon: Icons.speed,
                          color: scheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Top topics
                  Text('Top Topics', style: text.titleLarge),
                  const SizedBox(height: 12),
                  if (_topics != null && _topics!.isNotEmpty)
                    ..._topics!.map((topic) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.1),
                              child: Text(
                                '${topic['count']}',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(topic['topic']),
                            subtitle: Text('${topic['count']} queries'),
                          ),
                        ))
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No query data yet'),
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
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
