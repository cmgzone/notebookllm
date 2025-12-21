/// Represents a generated story
class Story {
  final String id;
  final String title;
  final StoryType type;
  final String content;
  final List<StoryChapter> chapters;
  final List<String> imageUrls;
  final String? coverImageUrl;
  final List<String> sources;
  final String? genre;
  final StoryLength length;
  final StoryTone tone;
  final List<StoryCharacter> characters;
  final String? setting;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Story({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    this.chapters = const [],
    this.imageUrls = const [],
    this.coverImageUrl,
    this.sources = const [],
    this.genre,
    this.length = StoryLength.medium,
    this.tone = StoryTone.neutral,
    this.characters = const [],
    this.setting,
    required this.createdAt,
    required this.updatedAt,
  });

  Story copyWith({
    String? title,
    String? content,
    List<StoryChapter>? chapters,
    List<String>? imageUrls,
    String? coverImageUrl,
    List<String>? sources,
    String? genre,
    StoryLength? length,
    StoryTone? tone,
    List<StoryCharacter>? characters,
    String? setting,
  }) {
    return Story(
      id: id,
      title: title ?? this.title,
      type: type,
      content: content ?? this.content,
      chapters: chapters ?? this.chapters,
      imageUrls: imageUrls ?? this.imageUrls,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      sources: sources ?? this.sources,
      genre: genre ?? this.genre,
      length: length ?? this.length,
      tone: tone ?? this.tone,
      characters: characters ?? this.characters,
      setting: setting ?? this.setting,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'content': content,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'imageUrls': imageUrls,
        'coverImageUrl': coverImageUrl,
        'sources': sources,
        'genre': genre,
        'length': length.name,
        'tone': tone.name,
        'characters': characters.map((c) => c.toJson()).toList(),
        'setting': setting,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Story.fromJson(Map<String, dynamic> json) => Story(
        id: json['id'],
        title: json['title'],
        type: StoryType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => StoryType.fiction,
        ),
        content: json['content'] ?? '',
        chapters: (json['chapters'] as List?)
                ?.map((c) => StoryChapter.fromJson(c))
                .toList() ??
            [],
        imageUrls: List<String>.from(json['imageUrls'] ?? []),
        coverImageUrl: json['coverImageUrl'],
        sources: List<String>.from(json['sources'] ?? []),
        genre: json['genre'],
        length: StoryLength.values.firstWhere(
          (e) => e.name == json['length'],
          orElse: () => StoryLength.medium,
        ),
        tone: StoryTone.values.firstWhere(
          (e) => e.name == json['tone'],
          orElse: () => StoryTone.neutral,
        ),
        characters: (json['characters'] as List?)
                ?.map((c) => StoryCharacter.fromJson(c))
                .toList() ??
            [],
        setting: json['setting'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

enum StoryType {
  realStory,
  fiction;

  String get displayName {
    switch (this) {
      case StoryType.realStory:
        return 'Real Story';
      case StoryType.fiction:
        return 'Fiction';
    }
  }

  String get description {
    switch (this) {
      case StoryType.realStory:
        return 'Based on real events with web-sourced images';
      case StoryType.fiction:
        return 'AI-generated creative story with AI images';
    }
  }
}

class StoryChapter {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final int order;
  final String? hook; // Opening hook for the chapter
  final String? cliffhanger; // Ending cliffhanger

  const StoryChapter({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.order,
    this.hook,
    this.cliffhanger,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'order': order,
        'hook': hook,
        'cliffhanger': cliffhanger,
      };

  factory StoryChapter.fromJson(Map<String, dynamic> json) => StoryChapter(
        id: json['id'],
        title: json['title'],
        content: json['content'] ?? '',
        imageUrl: json['imageUrl'],
        order: json['order'] ?? 0,
        hook: json['hook'],
        cliffhanger: json['cliffhanger'],
      );
}

/// Story length options
enum StoryLength {
  short,
  medium,
  long,
  epic;

  String get displayName {
    switch (this) {
      case StoryLength.short:
        return 'Short';
      case StoryLength.medium:
        return 'Medium';
      case StoryLength.long:
        return 'Long';
      case StoryLength.epic:
        return 'Epic';
    }
  }

  String get description {
    switch (this) {
      case StoryLength.short:
        return '2-3 chapters, ~1000 words';
      case StoryLength.medium:
        return '4-5 chapters, ~2500 words';
      case StoryLength.long:
        return '6-8 chapters, ~5000 words';
      case StoryLength.epic:
        return '10+ chapters, ~10000 words';
    }
  }

  int get chapterCount {
    switch (this) {
      case StoryLength.short:
        return 2;
      case StoryLength.medium:
        return 4;
      case StoryLength.long:
        return 7;
      case StoryLength.epic:
        return 10;
    }
  }

  int get wordsPerChapter {
    switch (this) {
      case StoryLength.short:
        return 500;
      case StoryLength.medium:
        return 600;
      case StoryLength.long:
        return 700;
      case StoryLength.epic:
        return 1000;
    }
  }
}

/// Story tone/mood options
enum StoryTone {
  neutral,
  dark,
  lighthearted,
  suspenseful,
  romantic,
  humorous,
  inspirational,
  melancholic;

  String get displayName {
    switch (this) {
      case StoryTone.neutral:
        return 'Neutral';
      case StoryTone.dark:
        return 'Dark';
      case StoryTone.lighthearted:
        return 'Lighthearted';
      case StoryTone.suspenseful:
        return 'Suspenseful';
      case StoryTone.romantic:
        return 'Romantic';
      case StoryTone.humorous:
        return 'Humorous';
      case StoryTone.inspirational:
        return 'Inspirational';
      case StoryTone.melancholic:
        return 'Melancholic';
    }
  }

  String get emoji {
    switch (this) {
      case StoryTone.neutral:
        return '📖';
      case StoryTone.dark:
        return '🌑';
      case StoryTone.lighthearted:
        return '☀️';
      case StoryTone.suspenseful:
        return '😰';
      case StoryTone.romantic:
        return '💕';
      case StoryTone.humorous:
        return '😄';
      case StoryTone.inspirational:
        return '✨';
      case StoryTone.melancholic:
        return '🌧️';
    }
  }
}

/// Character in a story
class StoryCharacter {
  final String name;
  final String role; // protagonist, antagonist, supporting
  final String description;
  final String? imageUrl;

  const StoryCharacter({
    required this.name,
    required this.role,
    required this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'description': description,
        'imageUrl': imageUrl,
      };

  factory StoryCharacter.fromJson(Map<String, dynamic> json) => StoryCharacter(
        name: json['name'] ?? '',
        role: json['role'] ?? 'supporting',
        description: json['description'] ?? '',
        imageUrl: json['imageUrl'],
      );
}
