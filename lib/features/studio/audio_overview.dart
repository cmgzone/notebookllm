import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_overview.freezed.dart';
part 'audio_overview.g.dart';

@freezed
class AudioOverview with _$AudioOverview {
  const factory AudioOverview({
    required String id,
    required String title,
    required String url,
    required Duration duration,
    required DateTime createdAt,
    @Default(false) bool isOffline,
  }) = _AudioOverview;

  factory AudioOverview.fromJson(Map<String, dynamic> json) => _$AudioOverviewFromJson(json);
}