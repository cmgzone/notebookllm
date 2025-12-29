import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import 'services/ai_model_service.dart';
import '../../core/ai/ai_models_provider.dart';

class AIModelsManagerScreen extends ConsumerStatefulWidget {
  const AIModelsManagerScreen({super.key});

  @override
  ConsumerState<AIModelsManagerScreen> createState() =>
      _AIModelsManagerScreenState();
}

class _AIModelsManagerScreenState extends ConsumerState<AIModelsManagerScreen> {
  bool _isLoading = false;
  List<AIModel> _models = [];

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    try {
      // Ensure table exists first (lazy migration)
      await ref.read(aiModelServiceProvider).ensureTableExists();
      final models = await ref.read(aiModelServiceProvider).listModels();
      setState(() {
        _models = models;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading models: $e')),
        );
      }
    }
  }

  void _showModelDialog([AIModel? model]) {
    showDialog(
      context: context,
      builder: (context) => _ModelDialog(
        model: model,
        onSave: () async {
          await _loadModels();
        },
      ),
    );
  }

  Future<void> _deleteModel(AIModel model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model?'),
        content: Text('Are you sure you want to delete "${model.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(aiModelServiceProvider).deleteModel(model.id);
      ref.invalidate(availableModelsProvider);
      await _loadModels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting model: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models Manager'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        actions: [
          IconButton(
            onPressed: () => _showModelDialog(),
            icon: const Icon(Icons.add),
            tooltip: 'Add Model',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _models.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.bot,
                          size: 64,
                          color: scheme.outline.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No AI Models configured',
                          style: TextStyle(color: scheme.outline)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _showModelDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Model'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _models.length,
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: scheme.outline.withValues(alpha: 0.1))),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: model.isActive
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          child: Icon(
                            LucideIcons.bot,
                            color: model.isActive
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(model.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            if (model.isPremium) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color:
                                          Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: const Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${model.provider} â€¢ ${model.modelId}'),
                            if (!model.isActive)
                              Text('Inactive',
                                  style: TextStyle(color: scheme.error)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showModelDialog(model),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _deleteModel(model),
                            ),
                          ],
                        ),
                      ),
                    ).animate().premiumFade(delay: (50 * index).ms);
                  },
                ),
    );
  }
}

class _ModelDialog extends ConsumerStatefulWidget {
  final AIModel? model;
  final VoidCallback onSave;

  const _ModelDialog({this.model, required this.onSave});

  @override
  ConsumerState<_ModelDialog> createState() => _ModelDialogState();
}

class _ModelDialogState extends ConsumerState<_ModelDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _modelIdController;
  late TextEditingController _descController;
  late TextEditingController _costInputController;
  late TextEditingController _costOutputController;
  late TextEditingController _contextController;
  String _provider = 'gemini';
  bool _isActive = true;
  bool _isPremium = false;
  bool _isSaving = false;

  final List<String> _providers = [
    'gemini',
    'openrouter',
    'openai',
    'anthropic'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.model?.name ?? '');
    _modelIdController =
        TextEditingController(text: widget.model?.modelId ?? '');
    _descController =
        TextEditingController(text: widget.model?.description ?? '');
    _costInputController = TextEditingController(
        text: widget.model?.costInput.toString() ?? '0.0');
    _costOutputController = TextEditingController(
        text: widget.model?.costOutput.toString() ?? '0.0');
    _contextController = TextEditingController(
        text: widget.model?.contextWindow.toString() ?? '0');
    _provider = widget.model?.provider ?? 'gemini';
    _isActive = widget.model?.isActive ?? true;
    _isPremium = widget.model?.isPremium ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final model = AIModel(
        id: widget.model?.id ?? '', // ID handled by DB for new items
        name: _nameController.text.trim(),
        modelId: _modelIdController.text.trim(),
        provider: _provider,
        description: _descController.text.trim(),
        costInput: double.tryParse(_costInputController.text) ?? 0.0,
        costOutput: double.tryParse(_costOutputController.text) ?? 0.0,
        contextWindow: int.tryParse(_contextController.text) ?? 0,
        isActive: _isActive,
        isPremium: _isPremium,
      );

      if (widget.model == null) {
        await ref.read(aiModelServiceProvider).addModel(model);
      } else {
        await ref.read(aiModelServiceProvider).updateModel(model);
      }
      ref.invalidate(availableModelsProvider);

      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      title: Text(widget.model == null ? 'Add AI Model' : 'Edit AI Model'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Display Name'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelIdController,
                decoration: const InputDecoration(
                    labelText: 'Model ID (API)', hintText: 'e.g. gpt-4o'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _provider,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: _providers
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _provider = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costInputController,
                      decoration: const InputDecoration(
                          labelText: 'Input Cost (\$)',
                          helperText: '/1k tokens'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costOutputController,
                      decoration: const InputDecoration(
                          labelText: 'Output Cost (\$)',
                          helperText: '/1k tokens'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contextController,
                decoration: const InputDecoration(
                  labelText: 'Context Window (tokens)',
                  helperText: 'Max tokens (e.g., 128000 for 128K)',
                  hintText: 'Leave 0 for auto-detect',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('128K', style: TextStyle(fontSize: 12)),
                    onPressed: () => _contextController.text = '128000',
                    backgroundColor: scheme.surfaceContainerHighest,
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    labelPadding: EdgeInsets.zero,
                  ),
                  ActionChip(
                    label: const Text('200K', style: TextStyle(fontSize: 12)),
                    onPressed: () => _contextController.text = '200000',
                    backgroundColor: scheme.surfaceContainerHighest,
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    labelPadding: EdgeInsets.zero,
                  ),
                  ActionChip(
                    label: const Text('1M', style: TextStyle(fontSize: 12)),
                    onPressed: () => _contextController.text = '1000000',
                    backgroundColor: scheme.surfaceContainerHighest,
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    labelPadding: EdgeInsets.zero,
                  ),
                  ActionChip(
                    label: const Text('2M', style: TextStyle(fontSize: 12)),
                    onPressed: () => _contextController.text = '2000000',
                    backgroundColor: scheme.surfaceContainerHighest,
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    labelPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Premium Model?'),
                subtitle: const Text('Requires subscription'),
                value: _isPremium,
                onChanged: (v) => setState(() => _isPremium = v!),
              ),
              CheckboxListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          label: Text(_isSaving ? 'Saving...' : 'Save'),
          icon: const Icon(Icons.save),
        ),
      ],
    );
  }
}