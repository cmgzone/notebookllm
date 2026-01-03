import '../sources/source.dart';

/// Builds enhanced context for GitHub sources in AI chat
/// Requirements: 2.1 - Include relevant GitHub source content in AI context
/// Requirements: 2.2 - Reference specific line numbers and code sections
/// Requirements: 2.4 - Maintain awareness of repository structure
class GitHubChatContextBuilder {
  /// Build context for a single GitHub source with enhanced formatting
  /// Requirements: 2.1, 2.2
  static String buildSourceContext(Source source,
      {int maxContentLength = 5000}) {
    if (!source.isGitHubSource) return '';

    final buffer = StringBuffer();

    // Header with GitHub metadata
    buffer.writeln('### GitHub File: ${source.title}');
    buffer.writeln('Repository: ${source.githubOwner}/${source.githubRepo}');
    buffer.writeln('Path: ${source.githubPath}');
    buffer.writeln('Branch: ${source.githubBranch ?? 'main'}');

    if (source.language != null) {
      buffer.writeln('Language: ${source.language}');
    }

    if (source.githubCommitSha != null) {
      buffer.writeln('Commit: ${source.githubCommitSha!.substring(0, 7)}');
    }

    // Add agent info if this was created by a coding agent
    if (source.hasAgentSession && source.agentName != null) {
      buffer.writeln('Added by: ${source.agentName} (coding agent)');
    }

    buffer.writeln();

    // Add code content with line numbers for reference
    // Requirements: 2.2 - Enable referencing specific line numbers
    final content = source.content;
    if (content.isNotEmpty) {
      buffer.writeln('```${source.language ?? ''}');

      // Add line numbers for easier reference
      final lines = content.split('\n');
      final truncatedLines = lines.length > 200 ? lines.sublist(0, 200) : lines;

      int lineNum = 1;
      int charCount = 0;

      for (final line in truncatedLines) {
        if (charCount >= maxContentLength) {
          buffer.writeln('... (truncated at line $lineNum)');
          break;
        }

        // Format: "  1 | code here"
        final lineNumStr = lineNum.toString().padLeft(4);
        final formattedLine = '$lineNumStr | $line';
        buffer.writeln(formattedLine);

        charCount += formattedLine.length;
        lineNum++;
      }

      if (lines.length > 200) {
        buffer.writeln('... (${lines.length - 200} more lines)');
      }

      buffer.writeln('```');
    }

    buffer.writeln();
    return buffer.toString();
  }

  /// Build repository structure context from multiple GitHub sources
  /// Requirements: 2.4 - Maintain awareness of repository structure
  static String buildRepoStructureContext(List<Source> githubSources) {
    if (githubSources.isEmpty) return '';

    // Group sources by repository
    final repoMap = <String, List<Source>>{};
    for (final source in githubSources) {
      if (!source.isGitHubSource) continue;

      final repoKey = '${source.githubOwner}/${source.githubRepo}';
      repoMap.putIfAbsent(repoKey, () => []).add(source);
    }

    if (repoMap.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('### Repository Structure Overview');

    for (final entry in repoMap.entries) {
      buffer.writeln('\n**${entry.key}**:');

      // Build a simple tree structure from paths
      final paths = entry.value
          .map((s) => s.githubPath)
          .whereType<String>()
          .toList()
        ..sort();

      // Group by directory
      final dirMap = <String, List<String>>{};
      for (final path in paths) {
        final parts = path.split('/');
        if (parts.length > 1) {
          final dir = parts.sublist(0, parts.length - 1).join('/');
          final file = parts.last;
          dirMap.putIfAbsent(dir, () => []).add(file);
        } else {
          dirMap.putIfAbsent('/', () => []).add(path);
        }
      }

      // Output structure
      for (final dirEntry in dirMap.entries) {
        if (dirEntry.key != '/') {
          buffer.writeln('  📁 ${dirEntry.key}/');
        }
        for (final file in dirEntry.value) {
          final indent = dirEntry.key != '/' ? '    ' : '  ';
          buffer.writeln('$indent📄 $file');
        }
      }
    }

    buffer.writeln();
    return buffer.toString();
  }

  /// Build context for related files in the same repository
  /// Requirements: 2.3 - Fetch and analyze related files from the same repository
  static String buildRelatedFilesContext(
    Source currentSource,
    List<Source> allSources,
  ) {
    if (!currentSource.isGitHubSource) return '';

    final relatedSources = allSources.where((s) {
      if (!s.isGitHubSource) return false;
      if (s.id == currentSource.id) return false;

      // Same repository
      return s.githubOwner == currentSource.githubOwner &&
          s.githubRepo == currentSource.githubRepo;
    }).toList();

    if (relatedSources.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('### Related Files in Same Repository');

    for (final source in relatedSources.take(5)) {
      buffer
          .writeln('- ${source.githubPath} (${source.language ?? 'unknown'})');
    }

    if (relatedSources.length > 5) {
      buffer.writeln('- ... and ${relatedSources.length - 5} more files');
    }

    buffer.writeln();
    return buffer.toString();
  }

  /// Build instructions for AI when GitHub sources are present
  static String buildGitHubInstructions() {
    return '''
=== GITHUB CODE INSTRUCTIONS ===
When discussing GitHub code sources:
1. Reference specific line numbers when pointing to code (e.g., "On line 42...")
2. Use code blocks with the appropriate language for any code snippets
3. When suggesting changes, show the original and modified code
4. If you identify issues or improvements, consider suggesting a GitHub issue
5. Be aware of the repository structure when discussing file relationships
''';
  }

  /// Detect if the user's query is asking about code analysis
  static bool isCodeAnalysisQuery(String query) {
    final lowerQuery = query.toLowerCase();
    final codeKeywords = [
      'code',
      'function',
      'class',
      'method',
      'variable',
      'bug',
      'error',
      'fix',
      'refactor',
      'optimize',
      'explain',
      'what does',
      'how does',
      'why',
      'line',
      'import',
      'export',
      'return',
      'analyze',
      'review',
      'improve',
    ];

    return codeKeywords.any((keyword) => lowerQuery.contains(keyword));
  }

  /// Detect if the user's query might result in an issue suggestion
  static bool mightSuggestIssue(String query) {
    final lowerQuery = query.toLowerCase();
    final issueKeywords = [
      'bug',
      'issue',
      'problem',
      'error',
      'fix',
      'broken',
      'wrong',
      'incorrect',
      'missing',
      'should',
      'need to',
      'must',
      'improve',
      'feature',
      'enhancement',
      'todo',
      'task',
    ];

    return issueKeywords.any((keyword) => lowerQuery.contains(keyword));
  }

  /// Detect if the user's query might result in a code suggestion
  static bool mightSuggestCode(String query) {
    final lowerQuery = query.toLowerCase();
    final codeKeywords = [
      'write',
      'create',
      'implement',
      'add',
      'change',
      'modify',
      'update',
      'refactor',
      'how to',
      'example',
      'show me',
      'code for',
      'function',
      'class',
      'method',
    ];

    return codeKeywords.any((keyword) => lowerQuery.contains(keyword));
  }
}
