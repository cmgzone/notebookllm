import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/tags/tag_provider.dart';

class BulkTagSheet extends ConsumerStatefulWidget {
  const BulkTagSheet({super.key});

  @override
  ConsumerState<BulkTagSheet> createState() => _BulkTagSheetState();
}

class _BulkTagSheetState extends ConsumerState<BulkTagSheet> {
  final Set<String> _selectedTagIds = {};

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Apply Tags',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (tags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                  'No tags created yet. Create tags in the standard view first.'),
            ),
          Wrap(
            spacing: 8,
            children: tags.map((tag) {
              final isSelected = _selectedTagIds.contains(tag.id);
              return FilterChip(
                label: Text(tag.name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTagIds.add(tag.id);
                    } else {
                      _selectedTagIds.remove(tag.id);
                    }
                  });
                },
                backgroundColor: isSelected
                    ? Color(int.parse(tag.color.replaceFirst('#', '0xFF')))
                        .withValues(alpha: 0.2)
                    : null,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Color(int.parse(tag.color.replaceFirst('#', '0xFF')))
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, _selectedTagIds.toList());
            },
            child: const Text('Apply Tags'),
          ),
        ],
      ),
    );
  }
}
