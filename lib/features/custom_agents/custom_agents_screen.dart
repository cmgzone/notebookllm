import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../agent_skills/agent_skill.dart';
import '../agent_skills/agent_skills_provider.dart';
import 'custom_agent.dart';
import 'custom_agents_provider.dart';

class CustomAgentsScreen extends ConsumerWidget {
  const CustomAgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customAgentsProvider);
    final skillsAsync = ref.watch(agentSkillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Agents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension),
            tooltip: 'Install Plugin',
            onPressed: () => _showInstallPluginDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Manage Skills',
            onPressed: () => context.push('/agent-skills'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : state.agents.isEmpty
                  ? const Center(child: Text('No custom agents yet.'))
                  : ListView.builder(
                      itemCount: state.agents.length,
                      itemBuilder: (context, index) {
                        final agent = state.agents[index];
                        final isSelected = state.selectedAgentId == agent.id;
                        return ListTile(
                          leading: Icon(isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked),
                          title: Text(agent.name),
                          subtitle: Text(agent.description ?? 'No description'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'edit') {
                                await _showAgentDialog(
                                  context,
                                  ref,
                                  agent,
                                  skillsAsync.valueOrNull ?? const [],
                                );
                              }
                              if (action == 'delete') {
                                await ref
                                    .read(customAgentsProvider.notifier)
                                    .delete(agent.id);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                          onTap: () => ref
                              .read(customAgentsProvider.notifier)
                              .setSelectedAgent(isSelected ? null : agent.id),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAgentDialog(
          context,
          ref,
          null,
          skillsAsync.valueOrNull ?? const [],
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAgentDialog(
    BuildContext context,
    WidgetRef ref,
    CustomAgent? existing,
    List<AgentSkill> allSkills,
  ) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final promptCtrl =
        TextEditingController(text: existing?.systemPrompt ?? '');
    final selectedSkillIds = <String>{...?(existing?.skillIds)};

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(existing == null ? 'Create Agent' : 'Edit Agent'),
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
                    controller: promptCtrl,
                    decoration:
                        const InputDecoration(labelText: 'System Prompt'),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  if (allSkills.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Skills',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  if (allSkills.isNotEmpty) const SizedBox(height: 8),
                  if (allSkills.isNotEmpty)
                    ...allSkills.map((skill) {
                      final checked = selectedSkillIds.contains(skill.id);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(skill.name),
                        subtitle: skill.description != null
                            ? Text(skill.description!)
                            : null,
                        value: checked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedSkillIds.add(skill.id);
                            } else {
                              selectedSkillIds.remove(skill.id);
                            }
                          });
                        },
                      );
                    }),
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
                  final systemPrompt = promptCtrl.text.trim();
                  if (name.isEmpty) return;

                  final id = existing?.id ??
                      ref.read(customAgentsProvider.notifier).generateId();
                  final agent = CustomAgent(
                    id: id,
                    name: name,
                    description:
                        descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    systemPrompt: systemPrompt,
                    skillIds: selectedSkillIds.toList(),
                  );

                  Navigator.pop(context);
                  await ref.read(customAgentsProvider.notifier).upsert(agent);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showInstallPluginDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final urlCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Install Plugin'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: 'Plugin manifest URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(context);
              await _installPluginFromUrl(context, ref, url);
            },
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }

  Future<void> _installPluginFromUrl(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final decoded = json.decode(resp.body);
      if (decoded is! Map) {
        throw Exception('Invalid plugin manifest');
      }

      final rawSkills = decoded['skills'];
      if (rawSkills is! List) {
        throw Exception('Plugin manifest missing skills');
      }

      final existingSkills = ref.read(agentSkillsProvider).valueOrNull ?? const [];
      final existingNames = existingSkills.map((s) => s.name.toLowerCase()).toSet();

      for (final item in rawSkills) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final name = map['name']?.toString().trim() ?? '';
        final content = map['content']?.toString().trim() ?? '';
        final description = map['description']?.toString().trim();
        final parameters = map['parameters'];

        if (name.isEmpty || content.isEmpty) continue;
        if (existingNames.contains(name.toLowerCase())) continue;

        await ref.read(agentSkillsProvider.notifier).createSkill(
              name: name,
              content: content,
              description: (description == null || description.isEmpty)
                  ? null
                  : description,
              parameters: parameters is Map<String, dynamic> ? parameters : null,
            );
      }

      messenger?.showSnackBar(
        const SnackBar(content: Text('Plugin installed')),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Install failed: $e')));
    }
  }
}
