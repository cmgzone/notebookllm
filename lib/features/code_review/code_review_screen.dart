import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'code_review_provider.dart';

class CodeReviewScreen extends ConsumerStatefulWidget {
  const CodeReviewScreen({super.key});

  @override
  ConsumerState<CodeReviewScreen> createState() => _CodeReviewScreenState();
}

class _CodeReviewScreenState extends ConsumerState<CodeReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  String _selectedLanguage = 'dart';
  String _selectedReviewType = 'comprehensive';

  final _languages = [
    'dart',
    'javascript',
    'typescript',
    'python',
    'java',
    'kotlin',
    'swift',
    'go',
    'rust',
    'c',
    'cpp',
    'csharp',
    'php',
    'ruby',
    'sql'
  ];

  final _reviewTypes = [
    ('comprehensive', 'Comprehensive', Icons.analytics),
    ('security', 'Security', Icons.security),
    ('performance', 'Performance', Icons.speed),
    ('readability', 'Readability', Icons.visibility),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load history on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(codeReviewProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(codeReviewProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Code Review'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'New Review', icon: Icon(Icons.rate_review)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewReviewTab(state, theme),
          _buildHistoryTab(state, theme),
        ],
      ),
    );
  }

  Widget _buildNewReviewTab(CodeReviewState state, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Language selector
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      isDense: true,
                      items: _languages.map((lang) {
                        return DropdownMenuItem(value: lang, child: Text(lang));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedLanguage = value);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Paste button
              IconButton(
                icon: const Icon(Icons.paste),
                tooltip: 'Paste from clipboard',
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _codeController.text = data!.text!;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Review type chips
          Wrap(
            spacing: 8,
            children: _reviewTypes.map((type) {
              final isSelected = _selectedReviewType == type.$1;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type.$3, size: 16),
                    const SizedBox(width: 4),
                    Text(type.$2),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedReviewType = type.$1);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Code input
          TextField(
            controller: _codeController,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Paste your code here',
              hintText: 'Enter or paste code to review...',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          FilledButton.icon(
            onPressed: state.isLoading ? null : _submitReview,
            icon: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rate_review),
            label: Text(state.isLoading ? 'Reviewing...' : 'Review Code'),
          ),
          const SizedBox(height: 24),

          // Results
          if (state.currentReview != null)
            _buildReviewResults(state.currentReview!, theme),
          if (state.error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(state.error!,
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewResults(CodeReview review, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Score card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildScoreIndicator(review.score, theme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quality Score', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(review.summary, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Issue counts
        Row(
          children: [
            _buildIssueCountChip(
                review.errorCount, 'Errors', Colors.red, theme),
            const SizedBox(width: 8),
            _buildIssueCountChip(
                review.warningCount, 'Warnings', Colors.orange, theme),
            const SizedBox(width: 8),
            _buildIssueCountChip(review.infoCount, 'Info', Colors.blue, theme),
          ],
        ),
        const SizedBox(height: 16),

        // Issues list
        if (review.issues.isNotEmpty) ...[
          Text('Issues Found', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...review.issues.map((issue) => _buildIssueCard(issue, theme)),
        ],

        // Suggestions
        if (review.suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Suggestions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...review.suggestions.map((s) => Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.lightbulb_outline, color: Colors.amber),
                  title: Text(s),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildScoreIndicator(int score, ThemeData theme) {
    Color color;
    if (score >= 90) {
      color = Colors.green;
    } else if (score >= 70) {
      color = Colors.lightGreen;
    } else if (score >= 50) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '$score',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCountChip(
      int count, String label, Color color, ThemeData theme) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text('$count',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
      label: Text(label),
    );
  }

  Widget _buildIssueCard(CodeReviewIssue issue, ThemeData theme) {
    Color severityColor;
    IconData severityIcon;
    switch (issue.severity) {
      case 'error':
        severityColor = Colors.red;
        severityIcon = Icons.error;
        break;
      case 'warning':
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      default:
        severityColor = Colors.blue;
        severityIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(severityIcon, color: severityColor),
        title: Text(issue.message),
        subtitle: Row(
          children: [
            Chip(
              label: Text(issue.category, style: const TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            if (issue.line != null) ...[
              const SizedBox(width: 8),
              Text('Line ${issue.line}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        children: [
          if (issue.suggestion != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suggestion:', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(issue.suggestion!),
                  if (issue.codeExample != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              issue.codeExample!,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: issue.codeExample!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(CodeReviewState state, ThemeData theme) {
    if (state.isLoading && state.history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No review history yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Submit your first code review to get started',
                style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(codeReviewProvider.notifier).loadHistory(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.history.length,
        itemBuilder: (context, index) {
          final item = state.history[index];
          return _buildHistoryCard(item, theme);
        },
      ),
    );
  }

  Widget _buildHistoryCard(CodeReviewHistoryItem item, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewReviewDetail(item.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildScoreIndicator(item.score, theme),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(item.language),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(item.reviewType),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.codePreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildSmallIssueChip(item.errorCount, Colors.red),
                      const SizedBox(width: 4),
                      _buildSmallIssueChip(item.warningCount, Colors.orange),
                      const SizedBox(width: 4),
                      _buildSmallIssueChip(item.infoCount, Colors.blue),
                    ],
                  ),
                  Text(
                    _formatDate(item.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallIssueChip(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _submitReview() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some code to review')),
      );
      return;
    }

    await ref.read(codeReviewProvider.notifier).reviewCode(
          code: _codeController.text,
          language: _selectedLanguage,
          reviewType: _selectedReviewType,
        );
  }

  Future<void> _viewReviewDetail(String reviewId) async {
    await ref.read(codeReviewProvider.notifier).getReviewDetail(reviewId);
    _tabController.animateTo(0); // Switch to review tab to show details
  }
}
