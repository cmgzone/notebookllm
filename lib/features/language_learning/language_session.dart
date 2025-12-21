import 'package:uuid/uuid.dart';

enum LanguageProficiency {
  beginner,
  intermediate,
  advanced,
  native,
}

enum LanguageRole {
  user,
  tutor,
  system,
}

class LanguageMessage {
  final String id;
  final LanguageRole role;
  final String content; // Original content (target language for tutor)
  final String? translation; // Translation to native language
  final String? correction; // Correction for user's message
  final String? pronunciation; // Pronunciation guide (IPA or phonetic)
  final DateTime timestamp;

  LanguageMessage({
    String? id,
    required this.role,
    required this.content,
    this.translation,
    this.correction,
    this.pronunciation,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'translation': translation,
        'correction': correction,
        'pronunciation': pronunciation,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LanguageMessage.fromJson(Map<String, dynamic> json) =>
      LanguageMessage(
        id: json['id'],
        role: LanguageRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => LanguageRole.system,
        ),
        content: json['content'],
        translation: json['translation'],
        correction: json['correction'],
        pronunciation: json['pronunciation'],
        timestamp: DateTime.parse(json['timestamp']),
      );

  LanguageMessage copyWith({
    String? content,
    String? translation,
    String? correction,
    String? pronunciation,
  }) {
    return LanguageMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      translation: translation ?? this.translation,
      correction: correction ?? this.correction,
      pronunciation: pronunciation ?? this.pronunciation,
      timestamp: timestamp,
    );
  }
}

class LanguageSession {
  final String id;
  final String targetLanguage;
  final String nativeLanguage; // User's language (e.g. English)
  final LanguageProficiency proficiency;
  final String? topic; // Optional focus topic
  final List<LanguageMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  LanguageSession({
    String? id,
    required this.targetLanguage,
    this.nativeLanguage = 'English',
    this.proficiency = LanguageProficiency.beginner,
    this.topic,
    this.messages = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetLanguage': targetLanguage,
        'nativeLanguage': nativeLanguage,
        'proficiency': proficiency.name,
        'topic': topic,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LanguageSession.fromJson(Map<String, dynamic> json) =>
      LanguageSession(
        id: json['id'],
        targetLanguage: json['targetLanguage'],
        nativeLanguage: json['nativeLanguage'] ?? 'English',
        proficiency: LanguageProficiency.values.firstWhere(
          (e) => e.name == json['proficiency'],
          orElse: () => LanguageProficiency.beginner,
        ),
        topic: json['topic'],
        messages: (json['messages'] as List?)
                ?.map((e) => LanguageMessage.fromJson(e))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  LanguageSession copyWith({
    List<LanguageMessage>? messages,
    DateTime? updatedAt,
  }) {
    return LanguageSession(
      id: id,
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
      proficiency: proficiency,
      topic: topic,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
