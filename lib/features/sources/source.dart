import 'package:freezed_annotation/freezed_annotation.dart';

part 'source.freezed.dart';
part 'source.g.dart';

@freezed
class Source with _$Source {
  const factory Source({
    required String id,
    required String notebookId,
    required String title,
    required String
        type, // drive, file, url, youtube, audio, text, image, github, code
    required DateTime addedAt,
    required String content, // raw text or transcript
    String? summary,
    DateTime? summaryGeneratedAt,
    String? imageUrl, // URL or base64 data URL for image sources
    String? thumbnailUrl, // Optional thumbnail for previews
    @Default([]) List<String> tagIds,
    @Default({})
    Map<String, dynamic>
        metadata, // Additional metadata (e.g., GitHub info, agent info)
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}

/// Extension methods for Source to check for GitHub and agent-related properties
extension SourceExtensions on Source {
  /// Check if this is a GitHub source
  bool get isGitHubSource => type == 'github';

  /// Check if this source was created by a coding agent
  bool get hasAgentSession => metadata['agentSessionId'] != null;

  /// Get the agent name if this source was created by an agent
  String? get agentName => metadata['agentName'] as String?;

  /// Get the agent session ID if this source was created by an agent
  String? get agentSessionId => metadata['agentSessionId'] as String?;

  /// Get GitHub owner if this is a GitHub source
  String? get githubOwner => metadata['owner'] as String?;

  /// Get GitHub repo if this is a GitHub source
  String? get githubRepo => metadata['repo'] as String?;

  /// Get GitHub path if this is a GitHub source
  String? get githubPath => metadata['path'] as String?;

  /// Get GitHub branch if this is a GitHub source
  String? get githubBranch => metadata['branch'] as String?;

  /// Get GitHub commit SHA if this is a GitHub source
  String? get githubCommitSha => metadata['commitSha'] as String?;

  /// Get the detected language if this is a GitHub source
  String? get language => metadata['language'] as String?;

  /// Get the GitHub URL if this is a GitHub source
  String? get githubUrl => metadata['githubUrl'] as String?;
}
