/// Sports news article model
class SportsNews {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String category;
  final String? imageUrl;
  final String source;
  final String sourceUrl;
  final DateTime publishedAt;
  final List<String> tags;
  final NewsImportance importance;

  SportsNews({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    this.imageUrl,
    required this.source,
    required this.sourceUrl,
    required this.publishedAt,
    this.tags = const [],
    this.importance = NewsImportance.normal,
  });

  factory SportsNews.fromJson(Map<String, dynamic> json) {
    return SportsNews(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'General',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      source: json['source'] ?? 'Unknown',
      sourceUrl: json['sourceUrl'] ?? json['source_url'] ?? '',
      publishedAt: DateTime.tryParse(
              json['publishedAt'] ?? json['published_at'] ?? '') ??
          DateTime.now(),
      tags: List<String>.from(json['tags'] ?? []),
      importance: NewsImportance.values.firstWhere(
        (e) => e.name == json['importance'],
        orElse: () => NewsImportance.normal,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'content': content,
        'category': category,
        'imageUrl': imageUrl,
        'source': source,
        'sourceUrl': sourceUrl,
        'publishedAt': publishedAt.toIso8601String(),
        'tags': tags,
        'importance': importance.name,
      };
}

enum NewsImportance {
  breaking,
  high,
  normal,
  low,
}

enum NewsCategory {
  all('All', '📰'),
  football('Football', '⚽'),
  basketball('Basketball', '🏀'),
  tennis('Tennis', '🎾'),
  formula1('Formula 1', '🏎️'),
  mma('MMA/UFC', '🥊'),
  transfers('Transfers', '🔄'),
  injuries('Injuries', '🏥'),
  results('Results', '🏆');

  final String displayName;
  final String emoji;

  const NewsCategory(this.displayName, this.emoji);
}
