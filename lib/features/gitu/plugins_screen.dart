import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_theme.dart';
import 'models/gitu_plugin.dart';
import 'models/plugin_catalog_item.dart';
import 'models/plugin_execution.dart';
import 'services/gitu_plugins_service.dart';

class GituPluginsScreen extends ConsumerWidget {
  const GituPluginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsAsync = ref.watch(gituPluginsProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.premiumGradient),
        ),
        title: const Text(
          'Plugins',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.store, color: Colors.white),
            onPressed: () => _openMarketplace(context, ref),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
            onPressed: () => ref.invalidate(gituPluginsProvider),
          ),
        ],
      ),
      body: pluginsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(gituPluginsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (plugins) {
          if (plugins.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.packagePlus, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No plugins yet'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openEditor(context, ref),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Create Plugin'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openMarketplace(context, ref),
                    icon: const Icon(LucideIcons.store),
                    label: const Text('Marketplace'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(gituPluginsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plugins.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _PluginTile(plugin: plugins[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, {GituPlugin? plugin}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PluginEditorSheet(existing: plugin),
    ).then((_) => ref.invalidate(gituPluginsProvider));
  }

  void _openMarketplace(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PluginMarketplaceSheet(),
    ).then((_) => ref.invalidate(gituPluginsProvider));
  }
}

class _PluginTile extends ConsumerWidget {
  final GituPlugin plugin;

  const _PluginTile({required this.plugin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plugin.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: plugin.enabled,
                  onChanged: (v) async {
                    try {
                      await ref.read(gituPluginsServiceProvider).updatePlugin(plugin.id, {
                        ...plugin.toPayload(),
                        'enabled': v,
                      });
                      ref.invalidate(gituPluginsProvider);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update plugin: $e')));
                    }
                  },
                ),
              ],
            ),
            if (plugin.description != null && plugin.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(plugin.description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(icon: LucideIcons.functionSquare, label: 'Entrypoint: ${plugin.entrypoint}'),
                const _Chip(icon: LucideIcons.shield, label: 'Sandboxed'),
                if (plugin.sourceCatalogId != null)
                  const _Chip(icon: LucideIcons.store, label: 'Marketplace'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditor(context, ref, plugin),
                  icon: const Icon(LucideIcons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openTest(context, ref, plugin),
                  icon: const Icon(LucideIcons.flaskConical, size: 16),
                  label: const Text('Test'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openHistory(context, ref, plugin),
                  icon: const Icon(LucideIcons.history, size: 16),
                  label: const Text('History'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(LucideIcons.trash2, color: Colors.red),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, GituPlugin plugin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PluginEditorSheet(existing: plugin),
    ).then((_) => ref.invalidate(gituPluginsProvider));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plugin?'),
        content: Text('This will permanently delete "${plugin.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(gituPluginsServiceProvider).deletePlugin(plugin.id);
      ref.invalidate(gituPluginsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plugin deleted')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete plugin: $e')));
    }
  }

  Future<void> _openTest(BuildContext context, WidgetRef ref, GituPlugin plugin) async {
    final inputController = TextEditingController(text: '{"path":"tmp/test.txt","content":"hello"}');
    final contextController = TextEditingController(text: '{"event":{"type":"manual"}}');
    final timeoutController = TextEditingController(text: '10000');

    bool running = false;
    Map<String, dynamic>? result;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final pretty = result == null ? null : const JsonEncoder.withIndent('  ').convert(result);
            return AlertDialog(
              title: Text('Test "${plugin.name}"'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Input (JSON object)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: inputController,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      const Text('Context (JSON object)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: contextController,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: timeoutController,
                        decoration: const InputDecoration(labelText: 'Timeout (ms)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                      if (pretty != null) ...[
                        const SizedBox(height: 12),
                        const Text('Result'),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(pretty, style: const TextStyle(fontFamily: 'monospace')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ElevatedButton.icon(
                  onPressed: running
                      ? null
                      : () async {
                          setState(() {
                            running = true;
                            result = null;
                            error = null;
                          });
                          try {
                            final input = GituPluginsService.tryParseJsonObject(inputController.text);
                            final ctx = GituPluginsService.tryParseJsonObject(contextController.text);
                            final timeout = int.tryParse(timeoutController.text.trim());
                            final exec = await ref.read(gituPluginsServiceProvider).executePlugin(
                              plugin.id,
                              input: input,
                              context: ctx,
                              timeoutMs: timeout,
                            );
                            setState(() => result = exec);
                          } catch (e) {
                            setState(() => error = 'Failed: $e');
                          } finally {
                            setState(() => running = false);
                          }
                        },
                  icon: running
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.play, size: 16),
                  label: const Text('Run'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openHistory(BuildContext context, WidgetRef ref, GituPlugin plugin) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PluginHistorySheet(plugin: plugin),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _PluginHistorySheet extends ConsumerStatefulWidget {
  final GituPlugin plugin;

  const _PluginHistorySheet({required this.plugin});

  @override
  ConsumerState<_PluginHistorySheet> createState() => _PluginHistorySheetState();
}

class _PluginHistorySheetState extends ConsumerState<_PluginHistorySheet> {
  bool _loading = false;
  List<PluginExecution> _executions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await ref.read(gituPluginsServiceProvider).listExecutions(widget.plugin.id, limit: 50, offset: 0);
      if (!mounted) return;
      setState(() => _executions = logs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load history: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Execution History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(onPressed: _loading ? null : _load, icon: const Icon(LucideIcons.refreshCw)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _executions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No executions yet'),
                ),
              if (_executions.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _executions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final e = _executions[index];
                      final icon = e.success ? LucideIcons.checkCircle2 : LucideIcons.xCircle;
                      final color = e.success ? Colors.green : Colors.red;
                      final subtitle = [
                        dateFmt.format(e.executedAt),
                        '${e.durationMs}ms',
                        if (e.error != null && e.error!.trim().isNotEmpty) e.error!,
                      ].join(' • ');
                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(e.success ? 'Success' : 'Failed'),
                        subtitle: Text(subtitle),
                        onTap: () => _showDetails(context, e),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, PluginExecution execution) {
    final pretty = execution.result == null ? null : const JsonEncoder.withIndent('  ').convert(execution.result);
    final logText = execution.logs.isEmpty ? null : execution.logs.join('\n');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Execution Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Success: ${execution.success}'),
                Text('Duration: ${execution.durationMs}ms'),
                if (execution.error != null && execution.error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Error: ${execution.error}', style: const TextStyle(color: Colors.red)),
                ],
                if (pretty != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(pretty, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ],
                if (logText != null) ...[
                  const SizedBox(height: 12),
                  const Text('Logs'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(logText, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _PluginMarketplaceSheet extends ConsumerStatefulWidget {
  const _PluginMarketplaceSheet();

  @override
  ConsumerState<_PluginMarketplaceSheet> createState() => _PluginMarketplaceSheetState();
}

class _PluginMarketplaceSheetState extends ConsumerState<_PluginMarketplaceSheet> {
  bool _loading = false;
  List<PluginCatalogItem> _items = const [];
  final TextEditingController _qController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ref.read(gituPluginsServiceProvider).listCatalog(q: _qController.text, limit: 100, offset: 0);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load marketplace: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Marketplace',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(onPressed: _loading ? null : _load, icon: const Icon(LucideIcons.refreshCw)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Search plugins',
                  suffixIcon: IconButton(
                    icon: const Icon(LucideIcons.search),
                    onPressed: _loading ? null : _load,
                  ),
                ),
                onSubmitted: (_) => _load(),
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No plugins found'),
                ),
              if (_items.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final subtitleParts = <String>[
                        if (item.author != null && item.author!.trim().isNotEmpty) item.author!,
                        item.version,
                      ];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          [
                            if (subtitleParts.isNotEmpty) subtitleParts.join(' • '),
                            if (item.description != null && item.description!.trim().isNotEmpty) item.description!,
                          ].where((s) => s.trim().isNotEmpty).join('\n'),
                        ),
                        trailing: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () async {
                                  setState(() => _loading = true);
                                  try {
                                    await ref.read(gituPluginsServiceProvider).installFromCatalog(item.id, config: const {}, enabled: true);
                                    if (!mounted) return;
                                    Navigator.of(this.context).pop();
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Install failed: $e')));
                                  } finally {
                                    if (mounted) setState(() => _loading = false);
                                  }
                                },
                          child: const Text('Install'),
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
  }
}

class _PluginEditorSheet extends ConsumerStatefulWidget {
  final GituPlugin? existing;

  const _PluginEditorSheet({required this.existing});

  @override
  ConsumerState<_PluginEditorSheet> createState() => _PluginEditorSheetState();
}

class _PluginEditorSheetState extends ConsumerState<_PluginEditorSheet> {
  bool _saving = false;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _entrypointController;
  late TextEditingController _configController;
  late TextEditingController _codeController;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _entrypointController = TextEditingController(text: existing?.entrypoint ?? 'run');
    _configController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(existing?.config ?? const {}),
    );
    _codeController = TextEditingController(text: existing?.code ?? _defaultTemplate());
    _enabled = existing?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _entrypointController.dispose();
    _configController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existing == null ? 'Create Plugin' : 'Edit Plugin',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _entrypointController,
                        decoration: const InputDecoration(labelText: 'Entrypoint', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: _enabled,
                      onChanged: _saving ? null : (v) => setState(() => _enabled = v),
                    ),
                    const Text('Enabled'),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _configController,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Config (JSON object)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  minLines: 12,
                  maxLines: 20,
                  decoration: const InputDecoration(
                    labelText: 'Code (JavaScript)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.save, size: 16),
                        label: Text(widget.existing == null ? 'Create' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _defaultTemplate() {
    return '''
module.exports = async (ctx) => {
  const input = ctx.input || {};
  const path = input.path || 'tmp/plugin.txt';
  const content = input.content || 'hello';
  await ctx.gitu.files.write(path, content);
  const read = await ctx.gitu.files.read(path);
  return { ok: true, read };
};
''';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      Map<String, dynamic> config;
      try {
        config = GituPluginsService.tryParseJsonObject(_configController.text);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Config invalid: $e')));
        return;
      }
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'code': _codeController.text,
        'entrypoint': _entrypointController.text.trim().isEmpty ? 'run' : _entrypointController.text.trim(),
        'config': config,
        'enabled': _enabled,
      };

      final validation = await ref.read(gituPluginsServiceProvider).validatePlugin(payload);
      final valid = validation['valid'] == true;
      if (!valid) {
        final errors = (validation['errors'] as List?)?.join(', ') ?? 'Invalid plugin';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errors)));
        return;
      }

      if (widget.existing == null) {
        await ref.read(gituPluginsServiceProvider).createPlugin(payload);
      } else {
        await ref.read(gituPluginsServiceProvider).updatePlugin(widget.existing!.id, payload);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save plugin: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
