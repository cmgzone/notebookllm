import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notebook/notebook_provider.dart';

class CreateNotebookDialog extends ConsumerStatefulWidget {
  const CreateNotebookDialog({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<CreateNotebookDialog> createState() =>
      _CreateNotebookDialogState();
}

class _CreateNotebookDialogState extends ConsumerState<CreateNotebookDialog> {
  final _controller = TextEditingController();
  final _customCategoryController = TextEditingController();
  bool _isCreating = false;
  late String _selectedCategory;
  late final List<String> _categories = [
    'General',
    'Work',
    'Study',
    'Personal',
    'Research',
    'Coding',
    'Creative'
  ];

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialCategory ?? 'General').trim();
    _selectedCategory = initial.isEmpty ? 'General' : initial;
    if (!_categories.contains(_selectedCategory)) {
      _categories.insert(0, _selectedCategory);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _createNotebook() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isCreating = true);

    try {
      await ref
          .read(notebookProvider.notifier)
          .addNotebook(_controller.text.trim(), category: _selectedCategory);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notebook created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create notebook: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create notebook', style: text.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_isCreating,
              decoration: const InputDecoration(labelText: 'Title'),
              onSubmitted: _isCreating ? null : (_) => _createNotebook(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _isCreating
                  ? null
                  : (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customCategoryController,
              enabled: !_isCreating,
              decoration: const InputDecoration(
                labelText: 'Custom category (optional)',
              ),
              onChanged: (value) {
                final next = value.trim();
                if (next.isEmpty) return;
                setState(() {
                  if (!_categories.contains(next)) {
                    _categories.insert(0, next);
                  }
                  _selectedCategory = next;
                });
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCreating ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isCreating ? null : _createNotebook,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(_isCreating ? 'Creating...' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
