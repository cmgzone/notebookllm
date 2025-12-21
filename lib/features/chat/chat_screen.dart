import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_provider.dart';
import 'message.dart';
import 'citation_drawer.dart';
import '../../core/theme/theme_provider.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          Consumer(builder: (context, ref, _) {
            final mode = ref.watch(themeModeProvider);
            return IconButton(
              icon: Icon(mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            );
          }),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.format_quote),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Citations',
            ),
          ),
        ],
      ),
      endDrawer: const CitationDrawer(),
      body: Column(
        children: [
          const _SourceFilters(),
          const Divider(height: 1),
          Expanded(child: _MessagesList(ref: ref, text: text)),
          const _PromptBar(),
        ],
      ),
    );
  }
}

class _SourceFilters extends StatelessWidget {
  const _SourceFilters();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.all(12),
      child: Row(children: [
        _FilterChip(label: 'All sources', selected: true),
        SizedBox(width: 8),
        _FilterChip(label: 'Drive'),
        SizedBox(width: 8),
        _FilterChip(label: 'PDF'),
        SizedBox(width: 8),
        _FilterChip(label: 'Web'),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      onSelected: (_) {},
      label: Text(label),
      selectedColor: scheme.primary.withValues(alpha: 0.12),
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList({required this.ref, required this.text});
  final WidgetRef ref;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final m = messages[index];
        return _MessageBubble(message: m);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Card(
          color: message.isUser ? scheme.primaryContainer : scheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text),
                if (message.citations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.format_quote, color: scheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Citations: ${message.citations.length}'),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptBar extends ConsumerStatefulWidget {
  const _PromptBar();

  @override
  ConsumerState<_PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends ConsumerState<_PromptBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(color: scheme.surface, boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -8)),
        ]),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Ask about your sources'),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              ref.read(chatProvider.notifier).send(text);
              _controller.clear();
            },
            child: const Text('Ask'),
          ),
        ]),
      ),
    );
  }
}