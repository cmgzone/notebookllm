import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_provider.dart';
import '../sources/source_detail_screen.dart';

class CitationDrawer extends ConsumerWidget {
  const CitationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatProvider);
    final citations = messages.expand((m) => m.citations).toList();
    final text = Theme.of(context).textTheme;

    return Drawer(
      width: 320,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Citations', style: text.titleLarge),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              if (citations.isEmpty)
                Text('Citations will appear here when grounded.', style: text.bodyMedium)
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: citations.length,
                    itemBuilder: (context, index) {
                      final c = citations[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(c.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Source ${c.sourceId}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SourceDetailScreen(sourceId: c.sourceId),
                                ),
                              );
                            },
                          ),
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