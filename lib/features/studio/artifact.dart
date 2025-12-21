import 'package:freezed_annotation/freezed_annotation.dart';

part 'artifact.freezed.dart';
part 'artifact.g.dart';

@freezed
class Artifact with _$Artifact {
  const factory Artifact({
    required String id,
    required String title,
    required String type, // study-guide, brief, faq, timeline, mind-map
    required String content,
    required DateTime createdAt,
    String? notebookId, // Associated notebook, null = global artifact
  }) = _Artifact;

  factory Artifact.fromJson(Map<String, dynamic> json) =>
      _$ArtifactFromJson(json);
}
