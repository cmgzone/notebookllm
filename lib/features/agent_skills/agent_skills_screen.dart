import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
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
        actions: [
          IconButton(
            onPressed: () => _showCatalogSheet(context, ref),
            icon: const Icon(Icons.storefront),
            tooltip: 'Skill Catalog',
          ),
        ],
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

  Future<void> _showCatalogSheet(BuildContext context, WidgetRef ref) async {
    final queryCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        String query = '';
        Future<List<Map<String, dynamic>>> future = ref
            .read(apiServiceProvider)
            .getAgentSkillsCatalog(query: query);

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> refresh() async {
              setState(() {
                future = ref
                    .read(apiServiceProvider)
                    .getAgentSkillsCatalog(query: query);
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.85,
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Skill Catalog',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: queryCtrl,
                        decoration: InputDecoration(
                          labelText: 'Search',
                          suffixIcon: IconButton(
                            onPressed: () {
                              queryCtrl.clear();
                              setState(() {
                                query = '';
                                future = ref
                                    .read(apiServiceProvider)
                                    .getAgentSkillsCatalog(query: query);
                              });
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        ),
                        onChanged: (value) {
                          query = value.trim();
                          refresh();
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: future,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            final items = snapshot.data ?? const [];
                            if (items.isEmpty) {
                              return const Center(
                                child: Text('No catalog skills available.'),
                              );
                            }

                            return RefreshIndicator(
                              onRefresh: refresh,
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final id = item['id']?.toString() ?? '';
                                  final name = item['name']?.toString() ?? '';
                                  final description =
                                      item['description']?.toString();

                                  return ListTile(
                                    title:
                                        Text(name.isEmpty ? 'Untitled' : name),
                                    subtitle: Text(
                                      (description == null ||
                                              description.isEmpty)
                                          ? 'No description'
                                          : description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: FilledButton(
                                      onPressed: id.isEmpty
                                          ? null
                                          : () async {
                                              try {
                                                await ref
                                                    .read(apiServiceProvider)
                                                    .installAgentSkillFromCatalog(
                                                      id,
                                                    );
                                                await ref
                                                    .read(agentSkillsProvider
                                                        .notifier)
                                                    .loadSkills();
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Installed "$name"'),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Install failed: $e'),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      child: const Text('Install'),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
