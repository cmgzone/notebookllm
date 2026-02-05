import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/ai/ai_models_provider.dart';
import '../../core/audio/voice_models_provider.dart';
import '../../theme/app_theme.dart';
import 'gitu_settings_provider.dart';
import 'gitu_settings_model.dart';
import 'gitu_proactive_dashboard.dart';

import 'whatsapp_connect_dialog.dart';

class GituSettingsScreen extends ConsumerWidget {
  const GituSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(gituSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
        ),
        title: const Text('Gitu Assistant Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Open Chat',
            onPressed: () => context.push('/gitu-chat'),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildEnableSection(context, ref, settings),
              const SizedBox(height: 20),
              if (settings.enabled) ...[
                // Proactive Dashboard - The main proactive insights feature
                const GituProactiveDashboard(),
                const SizedBox(height: 20),
                _buildConnectionStatusCard(context, ref, settings),
                const SizedBox(height: 20),
                _buildApiKeySection(context, ref, settings),
                const SizedBox(height: 20),
                _buildModelSelectionSection(context, ref, settings),
                const SizedBox(height: 20),
                _buildVoiceSection(context, ref, settings),
                const SizedBox(height: 20),
                _buildProactiveSection(context, ref, settings),
                const SizedBox(height: 20),
                _buildAnalyticsSection(context, ref, settings),
                const SizedBox(height: 20),
                _buildPlatformConnectionsSection(context, ref),
                const SizedBox(height: 20),
                _buildAssistantDataSection(context),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEnableSection(
      BuildContext context, WidgetRef ref, GituSettings settings) {
    return Card(
      elevation: 2,
      child: SwitchListTile(
        title: const Text('Enable Gitu Assistant'),
        subtitle: const Text(
            'Allow Gitu to run in the background and respond across platforms.'),
        value: settings.enabled,
        onChanged: (value) {
          ref.read(gituSettingsProvider.notifier).toggleEnabled(value);
        },
        secondary: const Icon(Icons.assistant),
      ),
    );
  }

  Widget _buildApiKeySection(
      BuildContext context, WidgetRef ref, GituSettings settings) {
    final prefs = settings.modelPreferences;
    final isPlatform = prefs.apiKeySource == 'platform';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('API Configuration',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              RadioGroup<String>(
                groupValue: prefs.apiKeySource,
                onChanged: (val) {
                  if (val == null) return;
                  ref
                      .read(gituSettingsProvider.notifier)
                      .updateModelPreferences(
                          prefs.copyWith(apiKeySource: val));
                },
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      title: Text('Use Platform Keys'),
                      subtitle:
                          Text('Use standard limits included in your plan'),
                      value: 'platform',
                    ),
                    RadioListTile<String>(
                      title: Text('Use Personal Keys'),
                      subtitle: Text('Use your own API keys for higher limits'),
                      value: 'personal',
                    ),
                  ],
                ),
              ),
              if (!isPlatform) _buildPersonalKeyInputs(context, ref, prefs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalKeyInputs(
      BuildContext context, WidgetRef ref, ModelPreferences prefs) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _KeyInput(
            label: 'OpenRouter Key',
            value: prefs.personalKeys['openrouter'] ?? '',
            onChanged: (val) {
              final newKeys = Map<String, String>.from(prefs.personalKeys);
              newKeys['openrouter'] = val;
              ref.read(gituSettingsProvider.notifier).updateModelPreferences(
                  prefs.copyWith(personalKeys: newKeys));
            },
          ),
          const SizedBox(height: 12),
          _KeyInput(
            label: 'Gemini Key',
            value: prefs.personalKeys['gemini'] ?? '',
            onChanged: (val) {
              final newKeys = Map<String, String>.from(prefs.personalKeys);
              newKeys['gemini'] = val;
              ref.read(gituSettingsProvider.notifier).updateModelPreferences(
                  prefs.copyWith(personalKeys: newKeys));
            },
          ),
          const SizedBox(height: 12),
          _KeyInput(
            label: 'Anthropic Key',
            value: prefs.personalKeys['anthropic'] ?? '',
            onChanged: (val) {
              final newKeys = Map<String, String>.from(prefs.personalKeys);
              newKeys['anthropic'] = val;
              ref.read(gituSettingsProvider.notifier).updateModelPreferences(
                  prefs.copyWith(personalKeys: newKeys));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelectionSection(
      BuildContext context, WidgetRef ref, GituSettings settings) {
    final prefs = settings.modelPreferences;
    final availableModelsAsync = ref.watch(availableModelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Model Selection', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: availableModelsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load models'),
              data: (modelsMap) {
                final allModels = modelsMap.values.expand((x) => x).toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

                return Column(
                  children: [
                    _ModelDropdown(
                      label: 'Default Model',
                      value: prefs.defaultModel,
                      items: allModels,
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(gituSettingsProvider.notifier)
                              .updateModelPreferences(
                                  prefs.copyWith(defaultModel: val));
                        }
                      },
                    ),
                    const Divider(),
                    _ModelDropdown(
                      label: 'Chat Model',
                      value: prefs.taskSpecificModels['chat'] ??
                          prefs.defaultModel,
                      items: allModels,
                      onChanged: (val) {
                        if (val != null) {
                          final newTasks = Map<String, String>.from(
                              prefs.taskSpecificModels);
                          newTasks['chat'] = val;
                          ref
                              .read(gituSettingsProvider.notifier)
                              .updateModelPreferences(
                                  prefs.copyWith(taskSpecificModels: newTasks));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _ModelDropdown(
                      label: 'Coding Model',
                      value: prefs.taskSpecificModels['coding'] ??
                          prefs.defaultModel,
                      items: allModels,
                      onChanged: (val) {
                        if (val != null) {
                          final newTasks = Map<String, String>.from(
                              prefs.taskSpecificModels);
                          newTasks['coding'] = val;
                          ref
                              .read(gituSettingsProvider.notifier)
                              .updateModelPreferences(
                                  prefs.copyWith(taskSpecificModels: newTasks));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _ModelDropdown(
                      label: 'Research Model',
                      value: prefs.taskSpecificModels['research'] ??
                          prefs.defaultModel,
                      items: allModels,
                      onChanged: (val) {
                        if (val != null) {
                          final newTasks = Map<String, String>.from(
                              prefs.taskSpecificModels);
                          newTasks['research'] = val;
                          ref
                              .read(gituSettingsProvider.notifier)
                              .updateModelPreferences(
                                  prefs.copyWith(taskSpecificModels: newTasks));
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatusCard(
      BuildContext context, WidgetRef ref, GituSettings settings) {
    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: const ListTile(
        leading: Icon(Icons.check_circle, color: Colors.green),
        title: Text('System Operational'),
        subtitle: Text('Gitu is active and listening for events.'),
      ),
    );
  }

  Widget _buildVoiceSection(
      BuildContext context, WidgetRef ref, GituSettings settings) {
    final voice = settings.voice;
    const providers = [
      {'id': 'murf', 'label': 'Murf (Recommended)'},
      {'id': 'elevenlabs', 'label': 'ElevenLabs'},
      {'id': 'google', 'label': 'Google'},
      {'id': 'google_cloud', 'label': 'Google Cloud'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Voice & Wake Word',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(voice.provider),
                  initialValue: voice.provider,
                  decoration: const InputDecoration(
                    labelText: 'Voice Provider',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: providers
                      .map((p) => DropdownMenuItem<String>(
                            value: p['id'],
                            child: Text(p['label'] ?? p['id']!),
                          ))
                      .toList(),
                  onChanged: (val) async {
                    if (val == null) return;
                    ref.read(gituSettingsProvider.notifier).updateVoiceSettings(
                          voice.copyWith(
                            provider: val,
                          ),
                        );
                  },
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final voicesAsync =
                        ref.watch(availableVoiceModelsProvider);
                    return voicesAsync.when(
                      loading: () =>
                          const LinearProgressIndicator(minHeight: 2),
                      error: (_, __) => const Text('Failed to load voices'),
                      data: (voices) {
                        final list = voices[voice.provider] ?? [];
                        final effectiveValue = list
                                .any((v) => v.voiceId == voice.voiceId)
                            ? voice.voiceId
                            : (list.isNotEmpty ? list.first.voiceId : '');
                        return DropdownButtonFormField<String>(
                          key: ValueKey('${voice.provider}_$effectiveValue'),
                          initialValue:
                              effectiveValue.isEmpty ? null : effectiveValue,
                          decoration: const InputDecoration(
                            labelText: 'Voice Selection',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: list
                              .map((v) => DropdownMenuItem<String>(
                                    value: v.voiceId,
                                    child: Text(v.name),
                                  ))
                              .toList(),
                          onChanged: (val) async {
                            if (val == null) return;
                            ref
                                .read(gituSettingsProvider.notifier)
                                .updateVoiceSettings(
                                  voice.copyWith(voiceId: val),
                                );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Wake Word'),
                  subtitle: const Text('Listen for "Hey Gitu" to activate'),
                  value: voice.wakeWordEnabled,
                  onChanged: (val) {
                    ref.read(gituSettingsProvider.notifier).updateWakeWord(
                          enabled: val,
                          alwaysListening:
                              val ? voice.alwaysListening : false,
                          phrase: voice.wakeWordPhrase,
                        );
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Always Listening (Background)'),
                  subtitle: const Text(
                      'Keeps the microphone active for wake word detection'),
                  value: voice.alwaysListening,
                  onChanged: voice.wakeWordEnabled
                      ? (val) {
                          ref
                              .read(gituSettingsProvider.notifier)
                              .updateWakeWord(
                                enabled: true,
                                alwaysListening: val,
                                phrase: voice.wakeWordPhrase,
                              );
                        }
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wake Word Phrase'),
                  subtitle: Text(voice.wakeWordPhrase),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final controller = TextEditingController(
                        text: voice.wakeWordPhrase);
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Wake Word Phrase'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'e.g. hey gitu',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(
                                context, controller.text.trim()),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (result != null && result.isNotEmpty) {
                      ref.read(gituSettingsProvider.notifier).updateWakeWord(
                            enabled: voice.wakeWordEnabled,
                            alwaysListening: voice.alwaysListening,
                            phrase: result,
                          );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProactiveSection(
      BuildContext context, WidgetRef ref, GituSettings settings) {
    final proactive = settings.proactive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Proactive Assistance',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable Proactive Insights'),
                subtitle: const Text(
                    'Generate suggestions and summaries automatically'),
                value: proactive.enabled,
                onChanged: (val) {
                  ref.read(gituSettingsProvider.notifier).updateProactiveSettings(
                        proactive.copyWith(enabled: val),
                      );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('High Priority Only'),
                subtitle: const Text('Notify only for urgent suggestions'),
                value: proactive.highPriorityOnly,
                onChanged: proactive.enabled
                    ? (val) {
                        ref
                            .read(gituSettingsProvider.notifier)
                            .updateProactiveSettings(
                              proactive.copyWith(highPriorityOnly: val),
                            );
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection(
      BuildContext context, WidgetRef ref, GituSettings settings) {
    final analytics = settings.analytics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Analytics & Insights',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable Usage Analytics'),
                subtitle: const Text('Track usage and performance metrics'),
                value: analytics.enabled,
                onChanged: (val) {
                  ref.read(gituSettingsProvider.notifier).updateAnalyticsSettings(
                        analytics.copyWith(enabled: val),
                      );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('View Analytics'),
                subtitle: const Text('Usage, costs, and task performance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu/analytics'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformConnectionsSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Platform Connections',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('GitHub'),
                subtitle: const Text('Manage repositories and issues'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/github'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Gmail'),
                subtitle: const Text('Connect for email reading and sending'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-gmail'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Google Calendar'),
                subtitle: const Text('Connect for events and scheduling'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-calendar'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: const Text('Shopify'),
                subtitle: const Text('Manage orders, products, and inventory'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-shopify'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.terminal),
                title: const Text('Terminal'),
                subtitle: const Text('CLI access via gitu command'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/agent-connections'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('WhatsApp'),
                subtitle: const Text('Connect via Baileys'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const WhatsAppConnectDialog(),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Telegram'),
                subtitle: const Text('Connect Bot to your NotebookLLM account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-linked-accounts'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantDataSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assistant Data', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.memory),
                title: const Text('Memories'),
                subtitle: const Text('View and manage assistant memories'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-memories'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Linked Accounts'),
                subtitle: const Text('Manage connected platforms'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-linked-accounts'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Scheduled Tasks'),
                subtitle: const Text('Manage background automation tasks'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-tasks'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.psychology),
                title: const Text('Autonomous Agents'),
                subtitle: const Text('Manage sub-agents and their tasks'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-agents'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_tree),
                title: const Text('Rules'),
                subtitle: const Text('Build IF-THEN automation rules'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-rules'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.extension),
                title: const Text('Plugins'),
                subtitle: const Text('Add and run sandboxed plugins'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-plugins'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('File Permissions'),
                subtitle: const Text('Manage allowed paths and view file logs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-file-permissions'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Permissions'),
                subtitle: const Text('View, approve, and revoke permissions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/gitu-permissions'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeyInput extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _KeyInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_KeyInput> createState() => _KeyInputState();
}

class _KeyInputState extends State<_KeyInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _KeyInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      obscureText: true,
      onChanged: widget.onChanged,
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<AIModelOption> items;
  final ValueChanged<String?> onChanged;

  const _ModelDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final exists = items.any((m) => m.id == value);
    final effectiveValue =
        exists ? value : (items.isNotEmpty ? items.first.id : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: effectiveValue,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: items.map((model) {
            return DropdownMenuItem(
              value: model.id,
              child: Text(
                model.name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
