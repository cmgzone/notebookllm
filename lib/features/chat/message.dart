import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String text,
    required bool isUser,
    required DateTime timestamp,
    @Default([]) List<Citation> citations,
    @Default([]) List<String> suggestedQuestions,
    @Default([]) List<SourceSuggestion> relatedSources,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

@freezed
class Citation with _$Citation {
  const factory Citation({
    required String id,
    required String sourceId,
    required String snippet,
    required int start,
    required int end,
  }) = _Citation;

  factory Citation.fromJson(Map<String, dynamic> json) =>
      _$CitationFromJson(json);
}

@freezed
class SourceSuggestion with _$SourceSuggestion {
  const factory SourceSuggestion({
    required String title,
    required String url,
    required String type, // 'youtube', 'article', etc.
    String? thumbnailUrl,
  }) = _SourceSuggestion;

  factory SourceSuggestion.fromJson(Map<String, dynamic> json) =>
      _$SourceSuggestionFromJson(json);
}
