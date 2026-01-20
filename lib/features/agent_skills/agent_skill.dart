class AgentSkill {
  final String id;
  final String name;
  final String? description;
  final String content;
  final Map<String, dynamic> parameters;
  final bool isActive;
  final DateTime createdAt;

  AgentSkill({
    required this.id,
    required this.name,
    this.description,
    required this.content,
    this.parameters = const {},
    this.isActive = true,
    required this.createdAt,
  });

  factory AgentSkill.fromJson(Map<String, dynamic> json) {
    return AgentSkill(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      content: json['content'],
      parameters: json['parameters'] ?? {},
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
