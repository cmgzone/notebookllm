import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_skills_provider.dart';
import 'agent_skill.dart';

class AgentSkillsScreen extends ConsumerWidget {
  const AgentSkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(agentSkillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Skills'),
      ),
      body: skillsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (skills) {
          if (skills.isEmpty) {
            return const Center(child: Text('No agent skills found.'));
          }
          return ListView.builder(
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];
              return ListTile(
                title: Text(skill.name),
                subtitle: Text(skill.description ?? 'No description'),
                trailing: Switch(
                  value: skill.isActive,
                  onChanged: (val) {
                    ref.read(agentSkillsProvider.notifier).updateSkill(
                          id: skill.id,
                          isActive: val,
                        );
                  },
                ),
                onTap: () => _showSkillDialog(context, ref, skill),
                onLongPress: () => _confirmDelete(context, ref, skill),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSkillDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSkillDialog(
      BuildContext context, WidgetRef ref, AgentSkill? skill) {
    final nameCtrl = TextEditingController(text: skill?.name ?? '');
    final descCtrl = TextEditingController(text: skill?.description ?? '');
    final contentCtrl = TextEditingController(text: skill?.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(skill == null ? 'Add Skill' : 'Edit Skill'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                decoration:
                    const InputDecoration(labelText: 'Content / Prompt'),
                maxLines: 5,
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
              final name = nameCtrl.text.trim();
              final content = contentCtrl.text.trim();
              if (name.isEmpty || content.isEmpty) return;

              Navigator.pop(context);

              if (skill == null) {
                await ref.read(agentSkillsProvider.notifier).createSkill(
                      name: name,
                      content: content,
                      description: descCtrl.text.trim(),
                    );
              } else {
                await ref.read(agentSkillsProvider.notifier).updateSkill(
                      id: skill.id,
                      name: name,
                      content: content,
                      description: descCtrl.text.trim(),
                    );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AgentSkill skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Skill?'),
        content: Text('Are you sure you want to delete "${skill.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(agentSkillsProvider.notifier).deleteSkill(skill.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
