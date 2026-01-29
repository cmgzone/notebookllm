import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_theme.dart';
import 'models/automation_rule.dart';
import 'models/rule_execution.dart';
import 'services/gitu_rules_service.dart';

class GituRulesScreen extends ConsumerWidget {
  const GituRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(gituRulesProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.premiumGradient),
        ),
        title: const Text(
          'Rules',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
            onPressed: () => ref.invalidate(gituRulesProvider),
          ),
        ],
      ),
      body: rulesAsync.when(
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
                onPressed: () => ref.invalidate(gituRulesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.gitBranchPlus, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No rules yet'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openEditor(context, ref),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Create Rule'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(gituRulesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _RuleTile(rule: rules[index]),
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

  void _openEditor(BuildContext context, WidgetRef ref, {AutomationRule? rule}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RuleEditorSheet(existing: rule),
    ).then((_) => ref.invalidate(gituRulesProvider));
  }
}

class _RuleTile extends ConsumerWidget {
  final AutomationRule rule;

  const _RuleTile({required this.rule});

  String _triggerLabel(Map<String, dynamic> trigger) {
    final type = trigger['type'];
    if (type == 'event') {
      final et = trigger['eventType'];
      if (et is String && et.trim().isNotEmpty) return 'Event: $et';
      return 'Event';
    }
    return 'Manual';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final triggerText = _triggerLabel(rule.trigger);

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
                    rule.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: rule.enabled,
                  onChanged: (v) async {
                    try {
                      await ref.read(gituRulesServiceProvider).updateRule(rule.id, {
                        ...rule.toPayload(),
                        'enabled': v,
                      });
                      ref.invalidate(gituRulesProvider);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update rule: $e')),
                      );
                    }
                  },
                ),
              ],
            ),
            if (rule.description != null && rule.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(rule.description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(icon: LucideIcons.zap, label: triggerText),
                _Chip(icon: LucideIcons.filter, label: 'If ${rule.conditions.length} condition(s)'),
                _Chip(icon: LucideIcons.play, label: 'Then ${rule.actions.length} action(s)'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditor(context, ref, rule),
                  icon: const Icon(LucideIcons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openTest(context, ref, rule),
                  icon: const Icon(LucideIcons.flaskConical, size: 16),
                  label: const Text('Test'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openHistory(context, ref, rule),
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

  void _openEditor(BuildContext context, WidgetRef ref, AutomationRule rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RuleEditorSheet(existing: rule),
    ).then((_) => ref.invalidate(gituRulesProvider));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('This will permanently delete "${rule.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(gituRulesServiceProvider).deleteRule(rule.id);
      ref.invalidate(gituRulesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rule deleted')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete rule: $e')));
    }
  }

  Future<void> _openTest(BuildContext context, WidgetRef ref, AutomationRule rule) async {
    final controller = TextEditingController();
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
              title: Text('Test "${rule.name}"'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Context (JSON object)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        minLines: 4,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '{"event":{"type":"manual"}}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
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
                            error = null;
                            result = null;
                          });
                          try {
                            final ctx = GituRulesService.tryParseJsonObject(controller.text);
                            final exec = await ref.read(gituRulesServiceProvider).executeRule(rule.id, context: ctx);
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

  Future<void> _openHistory(BuildContext context, WidgetRef ref, AutomationRule rule) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RuleHistorySheet(rule: rule),
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

class _RuleHistorySheet extends ConsumerStatefulWidget {
  final AutomationRule rule;

  const _RuleHistorySheet({required this.rule});

  @override
  ConsumerState<_RuleHistorySheet> createState() => _RuleHistorySheetState();
}

class _RuleHistorySheetState extends ConsumerState<_RuleHistorySheet> {
  bool _loading = false;
  List<RuleExecution> _executions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await ref.read(gituRulesServiceProvider).listExecutions(widget.rule.id, limit: 50, offset: 0);
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
                        if (e.matched) 'matched' else 'not matched',
                        dateFmt.format(e.executedAt),
                        if (e.error != null && e.error!.trim().isNotEmpty) e.error!,
                      ].join(' • ');
                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(e.success ? 'Success' : 'Failed'),
                        subtitle: Text(subtitle),
                        onTap: () => _showExecutionDetails(context, e),
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

  void _showExecutionDetails(BuildContext context, RuleExecution execution) {
    final pretty = execution.result == null
        ? null
        : const JsonEncoder.withIndent('  ').convert(execution.result);
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
                Text('Matched: ${execution.matched}'),
                Text('Success: ${execution.success}'),
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

class _RuleEditorSheet extends ConsumerStatefulWidget {
  final AutomationRule? existing;

  const _RuleEditorSheet({required this.existing});

  @override
  ConsumerState<_RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends ConsumerState<_RuleEditorSheet> {
  bool _saving = false;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  String _triggerType = 'manual';
  final TextEditingController _eventTypeController = TextEditingController();

  final List<_ConditionDraft> _conditions = [];
  final List<_ActionDraft> _actions = [];

  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _enabled = existing?.enabled ?? true;

    final trigger = existing?.trigger ?? const {'type': 'manual'};
    _triggerType = (trigger['type'] is String) ? trigger['type'] as String : 'manual';
    if (_triggerType == 'event') {
      final et = trigger['eventType'];
      if (et is String) _eventTypeController.text = et;
    }

    for (final c in existing?.conditions ?? const <Map<String, dynamic>>[]) {
      _conditions.add(_ConditionDraft.fromJson(c));
    }
    for (final a in existing?.actions ?? const <Map<String, dynamic>>[]) {
      _actions.add(_ActionDraft.fromJson(a));
    }
    if (_actions.isEmpty) _actions.add(_ActionDraft(type: 'files.list'));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _eventTypeController.dispose();
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
                        widget.existing == null ? 'Create Rule' : 'Edit Rule',
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
                      child: DropdownButtonFormField<String>(
                        initialValue: _triggerType,
                        decoration: const InputDecoration(labelText: 'Trigger', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'manual', child: Text('Manual')),
                          DropdownMenuItem(value: 'event', child: Text('Event')),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() => _triggerType = v);
                              },
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
                if (_triggerType == 'event') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _eventTypeController,
                    decoration: const InputDecoration(labelText: 'Event Type', border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 20),
                _sectionHeader(context, 'IF (Conditions)', onAdd: () {
                  setState(() => _conditions.add(_ConditionDraft()));
                }),
                const SizedBox(height: 8),
                if (_conditions.isEmpty)
                  const Text('No conditions (rule always matches trigger)'),
                for (int i = 0; i < _conditions.length; i++) ...[
                  const SizedBox(height: 8),
                  _ConditionEditor(
                    draft: _conditions[i],
                    onRemove: () => setState(() => _conditions.removeAt(i)),
                  ),
                ],
                const SizedBox(height: 20),
                _sectionHeader(context, 'THEN (Actions)', onAdd: () {
                  setState(() => _actions.add(_ActionDraft(type: 'files.list')));
                }),
                const SizedBox(height: 8),
                for (int i = 0; i < _actions.length; i++) ...[
                  const SizedBox(height: 8),
                  _ActionEditor(
                    draft: _actions[i],
                    onRemove: _actions.length <= 1 ? null : () => setState(() => _actions.removeAt(i)),
                  ),
                ],
                const SizedBox(height: 20),
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

  Widget _sectionHeader(BuildContext context, String title, {required VoidCallback onAdd}) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
        IconButton(onPressed: _saving ? null : onAdd, icon: const Icon(LucideIcons.plus)),
      ],
    );
  }

  Map<String, dynamic> _buildTrigger() {
    if (_triggerType == 'event') {
      return {
        'type': 'event',
        'eventType': _eventTypeController.text.trim(),
      };
    }
    return {'type': 'manual'};
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'trigger': _buildTrigger(),
        'conditions': _conditions.map((c) => c.toJson()).toList(),
        'actions': _actions.map((a) => a.toJson()).toList(),
        'enabled': _enabled,
      };

      final validation = await ref.read(gituRulesServiceProvider).validateRule(payload);
      final valid = validation['valid'] == true;
      if (!valid) {
        final errors = (validation['errors'] as List?)?.join(', ') ?? 'Invalid rule';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errors)));
        return;
      }

      if (widget.existing == null) {
        await ref.read(gituRulesServiceProvider).createRule(payload);
      } else {
        await ref.read(gituRulesServiceProvider).updateRule(widget.existing!.id, payload);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save rule: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ConditionDraft {
  String type;
  String path;
  String valueType;
  String valueRaw;

  _ConditionDraft({
    this.type = 'exists',
    this.path = '',
    this.valueType = 'string',
    this.valueRaw = '',
  });

  factory _ConditionDraft.fromJson(Map<String, dynamic> json) {
    final t = json['type'];
    final p = json['path'];
    final v = json['value'];
    if (t == 'equals') {
      final vt = v is bool ? 'bool' : v is num ? 'number' : 'string';
      return _ConditionDraft(
        type: 'equals',
        path: p is String ? p : '',
        valueType: vt,
        valueRaw: v == null ? '' : '$v',
      );
    }
    if (t == 'contains') {
      return _ConditionDraft(type: 'contains', path: p is String ? p : '', valueRaw: v is String ? v : '');
    }
    return _ConditionDraft(type: 'exists', path: p is String ? p : '');
  }

  Map<String, dynamic> toJson() {
    final p = path.trim();
    if (type == 'equals') {
      dynamic value;
      final raw = valueRaw.trim();
      if (valueType == 'number') {
        value = num.tryParse(raw);
      } else if (valueType == 'bool') {
        value = raw.toLowerCase() == 'true';
      } else {
        value = raw;
      }
      return {'type': 'equals', 'path': p, 'value': value};
    }
    if (type == 'contains') {
      return {'type': 'contains', 'path': p, 'value': valueRaw};
    }
    return {'type': 'exists', 'path': p};
  }
}

class _ConditionEditor extends StatefulWidget {
  final _ConditionDraft draft;
  final VoidCallback onRemove;

  const _ConditionEditor({required this.draft, required this.onRemove});

  @override
  State<_ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends State<_ConditionEditor> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: d.type,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'exists', child: Text('Exists')),
                      DropdownMenuItem(value: 'equals', child: Text('Equals')),
                      DropdownMenuItem(value: 'contains', child: Text('Contains')),
                    ],
                    onChanged: (v) => setState(() => d.type = v ?? 'exists'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: widget.onRemove, icon: const Icon(LucideIcons.trash2, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: d.path,
              decoration: const InputDecoration(labelText: 'Path (dot notation)', border: OutlineInputBorder()),
              onChanged: (v) => d.path = v,
            ),
            if (d.type == 'equals') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: d.valueType,
                      decoration: const InputDecoration(labelText: 'Value Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'string', child: Text('String')),
                        DropdownMenuItem(value: 'number', child: Text('Number')),
                        DropdownMenuItem(value: 'bool', child: Text('Boolean')),
                      ],
                      onChanged: (v) => setState(() => d.valueType = v ?? 'string'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: d.valueRaw,
                      decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
                      onChanged: (v) => d.valueRaw = v,
                    ),
                  ),
                ],
              ),
            ],
            if (d.type == 'contains') ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: d.valueRaw,
                decoration: const InputDecoration(labelText: 'Contains', border: OutlineInputBorder()),
                onChanged: (v) => d.valueRaw = v,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionDraft {
  String type;
  String path;
  String content;
  String command;
  String argsRaw;
  String cwd;
  String timeoutMsRaw;
  bool sandboxed;

  _ActionDraft({
    required this.type,
    this.path = '',
    this.content = '',
    this.command = '',
    this.argsRaw = '',
    this.cwd = '',
    this.timeoutMsRaw = '',
    this.sandboxed = true,
  });

  factory _ActionDraft.fromJson(Map<String, dynamic> json) {
    final t = json['type'];
    if (t == 'shell.execute') {
      return _ActionDraft(
        type: 'shell.execute',
        command: (json['command'] is String) ? json['command'] as String : '',
        argsRaw: (json['args'] is List) ? (json['args'] as List).map((e) => '$e').join(' ') : '',
        cwd: (json['cwd'] is String) ? json['cwd'] as String : '',
        timeoutMsRaw: (json['timeoutMs'] != null) ? '${json['timeoutMs']}' : '',
        sandboxed: json['sandboxed'] != false,
      );
    }
    if (t == 'files.write') {
      return _ActionDraft(
        type: 'files.write',
        path: (json['path'] is String) ? json['path'] as String : '',
        content: (json['content'] is String) ? json['content'] as String : '',
      );
    }
    if (t == 'files.read') {
      return _ActionDraft(type: 'files.read', path: (json['path'] is String) ? json['path'] as String : '');
    }
    return _ActionDraft(type: 'files.list', path: (json['path'] is String) ? json['path'] as String : '');
  }

  Map<String, dynamic> toJson() {
    if (type == 'shell.execute') {
      final args = argsRaw
          .split(RegExp(r'\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final timeout = int.tryParse(timeoutMsRaw.trim());
      final out = <String, dynamic>{
        'type': 'shell.execute',
        'command': command.trim(),
        if (args.isNotEmpty) 'args': args,
        if (cwd.trim().isNotEmpty) 'cwd': cwd.trim(),
        if (timeout != null) 'timeoutMs': timeout,
        'sandboxed': sandboxed,
      };
      return out;
    }
    if (type == 'files.write') {
      return {'type': 'files.write', 'path': path.trim(), 'content': content};
    }
    if (type == 'files.read') {
      return {'type': 'files.read', 'path': path.trim()};
    }
    return {'type': 'files.list', 'path': path.trim()};
  }
}

class _ActionEditor extends StatefulWidget {
  final _ActionDraft draft;
  final VoidCallback? onRemove;

  const _ActionEditor({required this.draft, required this.onRemove});

  @override
  State<_ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<_ActionEditor> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: d.type,
                    decoration: const InputDecoration(labelText: 'Action', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'files.list', child: Text('Files: List')),
                      DropdownMenuItem(value: 'files.read', child: Text('Files: Read')),
                      DropdownMenuItem(value: 'files.write', child: Text('Files: Write')),
                      DropdownMenuItem(value: 'shell.execute', child: Text('Shell: Execute')),
                    ],
                    onChanged: (v) => setState(() => d.type = v ?? 'files.list'),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.onRemove != null)
                  IconButton(onPressed: widget.onRemove, icon: const Icon(LucideIcons.trash2, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 12),
            if (d.type.startsWith('files.')) ...[
              TextFormField(
                initialValue: d.path,
                decoration: const InputDecoration(labelText: 'Path', border: OutlineInputBorder()),
                onChanged: (v) => d.path = v,
              ),
            ],
            if (d.type == 'files.write') ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: d.content,
                decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
                minLines: 2,
                maxLines: 6,
                onChanged: (v) => d.content = v,
              ),
            ],
            if (d.type == 'shell.execute') ...[
              TextFormField(
                initialValue: d.command,
                decoration: const InputDecoration(labelText: 'Command', border: OutlineInputBorder()),
                onChanged: (v) => d.command = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: d.argsRaw,
                decoration: const InputDecoration(labelText: 'Args (space separated)', border: OutlineInputBorder()),
                onChanged: (v) => d.argsRaw = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: d.cwd,
                      decoration: const InputDecoration(labelText: 'CWD', border: OutlineInputBorder()),
                      onChanged: (v) => d.cwd = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: d.timeoutMsRaw,
                      decoration: const InputDecoration(labelText: 'Timeout (ms)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => d.timeoutMsRaw = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: d.sandboxed,
                    onChanged: (v) => setState(() => d.sandboxed = v),
                  ),
                  const Text('Sandboxed'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
