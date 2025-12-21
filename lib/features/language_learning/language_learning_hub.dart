import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../gamification/gamification_provider.dart';
import 'language_learning_provider.dart';
import 'language_session.dart';

class LanguageLearningHub extends ConsumerWidget {
  const LanguageLearningHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(languageLearningProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Learning'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _StatsHeader(state: ref.watch(gamificationProvider)),
          Expanded(
            child: sessions.isEmpty
                ? _buildEmptyState(context, ref, scheme, text)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _SessionCard(session: session)
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: index * 50))
                          .slideY(begin: 0.1);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewSessionDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, WidgetRef ref, ColorScheme scheme, TextTheme text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.languages,
                size: 64,
                color: scheme.primary,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'Start Learning a Language',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Practice conversations, learn vocabulary, and improve your grammar with AI tutors.',
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () =>
                  _showNewSessionDialog(context, ref), // Fix: Pass ref
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start First Session'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewSessionDialog(BuildContext context, WidgetRef ref) {
    final languages = [
      'Spanish',
      'French',
      'German',
      'Italian',
      'Japanese',
      'Korean',
      'Chinese',
      'Russian',
      'Portuguese'
    ];
    String selectedLanguage = languages.first;
    LanguageProficiency selectedProficiency = LanguageProficiency.beginner;
    final topicController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Language Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Language'),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLanguage,
                      isDense: true,
                      isExpanded: true,
                      items: languages
                          .map(
                              (l) => DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedLanguage = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Proficiency'),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<LanguageProficiency>(
                      value: selectedProficiency,
                      isDense: true,
                      isExpanded: true,
                      items: LanguageProficiency.values
                          .map((p) => DropdownMenuItem(
                              value: p, child: Text(p.name.toUpperCase())))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedProficiency = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Topic (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Ordering food, Travel, Business',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final session = await ref
                    .read(languageLearningProvider.notifier)
                    .startSession(
                      targetLanguage: selectedLanguage,
                      proficiency: selectedProficiency,
                      topic: topicController.text.trim().isEmpty
                          ? null
                          : topicController.text.trim(),
                    );
                if (context.mounted) {
                  context.push('/language-learning/${session.id}');
                }
              },
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final LanguageSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            session.targetLanguage.substring(0, 2).toUpperCase(),
            style: TextStyle(
                color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          session.targetLanguage,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
                '${session.proficiency.name} • ${session.topic ?? "General Conversation"}'),
            const SizedBox(height: 4),
            Text(
              'Last active: ${_formatDate(session.updatedAt)}',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push('/language-learning/${session.id}'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}

class _StatsHeader extends StatelessWidget {
  final GamificationState state;

  const _StatsHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            icon: Icons.local_fire_department,
            color: Colors.orange,
            value: state.stats.currentStreak.toString(),
            label: 'Day Streak',
          ),
          Container(
            height: 32,
            width: 1,
            color: scheme.outlineVariant,
          ),
          _StatItem(
            icon: LucideIcons.gem,
            color: Colors.blue,
            value: state.stats.totalXp.toString(),
            label: 'Total XP',
          ),
          Container(
            height: 32,
            width: 1,
            color: scheme.outlineVariant,
          ),
          _StatItem(
            icon: LucideIcons.crown,
            color: Colors.purple,
            value: (state.stats.level).toString(),
            label: 'Level',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(
              value,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: text.labelSmall,
        ),
      ],
    );
  }
}
