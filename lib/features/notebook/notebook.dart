import 'package:freezed_annotation/freezed_annotation.dart';

part 'notebook.freezed.dart';
part 'notebook.g.dart';

@freezed
class Notebook with _$Notebook {
  const factory Notebook({
    required String id,
    required String userId,
    required String title,
    @Default('') String description,
    String? coverImage, // Base64 encoded image or URL
    required int sourceCount,
    required DateTime createdAt,
    required DateTime updatedAt,
    // Agent notebook fields (Requirements 1.4, 4.1)
    @Default(false) bool isAgentNotebook,
    String? agentSessionId,
    String? agentName,
    String? agentIdentifier,
    @Default('active')
    String agentStatus, // 'active', 'expired', 'disconnected'
    @Default('General') String category,
  }) = _Notebook;

  factory Notebook.fromJson(Map<String, dynamic> json) =>
      _$NotebookFromJson(json);
}
