import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'memory_provider.dart';

class GituMemoryScreen extends ConsumerStatefulWidget {
  const GituMemoryScreen({super.key});

  @override
  ConsumerState<GituMemoryScreen> createState() => _GituMemoryScreenState();
}

class _GituMemoryScreenState extends ConsumerState<GituMemoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _categories = const ['all', 'personal', 'work', 'preference', 'fact', 'context'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final cat = _categories[_tabController.index];
      ref.read(gituMemoryProvider.notifier).setCategoryFilter(cat == 'all' ? null : cat);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gituMemoryProvider.notifier).loadMemories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gituMemoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _categories.map((c) => Tab(text: c.toUpperCase())).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search memories',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(gituMemoryProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(gituMemoryProvider.notifier).setSearchQuery(value);
              },
            ),
          ),
          if (state.isLoading)
            const LinearProgressIndicator()
          else if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error!, style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(gituMemoryProvider.notifier).loadMemories(),
              child: ListView.builder(
                itemCount: state.memories.length,
                itemBuilder: (context, index) {
                  final m = state.memories[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(m.content),
                      subtitle: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _chip('Category: ${m.category}', Colors.blueGrey),
                          _chip('Source: ${m.source}', Colors.indigo),
                          _chip('Conf: ${m.confidence.toStringAsFixed(2)}', Colors.teal),
                          if (m.verified)
                            _statusChip('Verified', Colors.green)
                          else if (m.verificationRequired)
                            _statusChip('Needs Verification', Colors.orange)
                          else
                            _statusChip('Unverified', Colors.grey),
                          for (final tag in m.tags) _chip(tag, Colors.blue),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          final notifier = ref.read(gituMemoryProvider.notifier);
                          if (value == 'confirm') {
                            await notifier.confirmMemory(m.id);
                          } else if (value == 'verify') {
                            await notifier.requestVerification(m.id);
                          } else if (value == 'edit') {
                            await _showEditDialog(m);
                          } else if (value == 'delete') {
                            await notifier.deleteMemory(m.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'confirm', child: Text('Confirm')),
                          const PopupMenuItem(value: 'verify', child: Text('Request Verification')),
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(GituMemory m) async {
    final controller = TextEditingController(text: m.content);
    String selectedCategory = m.category;
    final parentContext = context;
    await showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Memory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                items: _categories
                    .where((c) => c != 'all')
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                  }
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(gituMemoryProvider.notifier).correctMemory(
                      m.id,
                      content: controller.text.trim(),
                      category: selectedCategory,
                    );
                if (!parentContext.mounted) return;
                Navigator.of(parentContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String text, Color color) {
    return Chip(
      label: Text(text),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color),
      shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.6))),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Chip(
      avatar: Icon(Icons.check_circle, color: color, size: 18),
      label: Text(text),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color),
      shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.6))),
    );
  }
}
