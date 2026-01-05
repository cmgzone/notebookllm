import 'package:freezed_annotation/freezed_annotation.dart';

part 'requirement.freezed.dart';
part 'requirement.g.dart';

/// EARS pattern types for requirements (Requirements 4.2)
enum EarsPattern {
  ubiquitous, // THE <system> SHALL <response>
  event, // WHEN <trigger>, THE <system> SHALL <response>
  state, // WHILE <condition>, THE <system> SHALL <response>
  unwanted, // IF <condition>, THEN THE <system> SHALL <response>
  optional, // WHERE <option>, THE <system> SHALL <response>
  complex, // Combination of patterns
}

/// Represents a requirement in a plan following EARS patterns
/// Requirements: 4.1, 4.2
@freezed
class Requirement with _$Requirement {
  const factory Requirement({
    required String id,
    required String planId,
    required String title,
    @Default('') String description,
    @Default(EarsPattern.ubiquitous) EarsPattern earsPattern,
    @Default([]) List<String> acceptanceCriteria,
    @Default(0) int sortOrder,
    required DateTime createdAt,
  }) = _Requirement;

  const Requirement._();

  factory Requirement.fromJson(Map<String, dynamic> json) =>
      _$RequirementFromJson(json);

  factory Requirement.fromBackendJson(Map<String, dynamic> json) {
    final acceptanceCriteriaData =
        json['acceptanceCriteria'] ?? json['acceptance_criteria'];

    return Requirement(
      id: json['id'] as String? ?? '',
      planId: (json['planId'] ?? json['plan_id']) as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      earsPattern: _parseEarsPattern(
          (json['earsPattern'] ?? json['ears_pattern']) as String?),
      acceptanceCriteria:
          acceptanceCriteriaData != null && acceptanceCriteriaData is List
              ? List<String>.from(acceptanceCriteriaData)
              : <String>[],
      sortOrder: (json['sortOrder'] ?? json['sort_order'] ?? 0) as int,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
    );
  }

  /// Convert to backend JSON format
  Map<String, dynamic> toBackendJson() => {
        'id': id,
        'plan_id': planId,
        'title': title,
        'description': description,
        'ears_pattern': earsPattern.name,
        'acceptance_criteria': acceptanceCriteria,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  /// Get the EARS pattern template
  String get earsTemplate {
    switch (earsPattern) {
      case EarsPattern.ubiquitous:
        return 'THE <system> SHALL <response>';
      case EarsPattern.event:
        return 'WHEN <trigger>, THE <system> SHALL <response>';
      case EarsPattern.state:
        return 'WHILE <condition>, THE <system> SHALL <response>';
      case EarsPattern.unwanted:
        return 'IF <condition>, THEN THE <system> SHALL <response>';
      case EarsPattern.optional:
        return 'WHERE <option>, THE <system> SHALL <response>';
      case EarsPattern.complex:
        return '[WHERE] [WHILE] [WHEN/IF] THE <system> SHALL <response>';
    }
  }

  static EarsPattern _parseEarsPattern(String? pattern) {
    switch (pattern) {
      case 'ubiquitous':
        return EarsPattern.ubiquitous;
      case 'event':
        return EarsPattern.event;
      case 'state':
        return EarsPattern.state;
      case 'unwanted':
        return EarsPattern.unwanted;
      case 'optional':
        return EarsPattern.optional;
      case 'complex':
        return EarsPattern.complex;
      default:
        return EarsPattern.ubiquitous;
    }
  }
}
