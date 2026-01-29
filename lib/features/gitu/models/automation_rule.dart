class AutomationRule {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final Map<String, dynamic> trigger;
  final List<Map<String, dynamic>> conditions;
  final List<Map<String, dynamic>> actions;
  final bool enabled;
  final DateTime? createdAt;

  AutomationRule({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.trigger,
    required this.conditions,
    required this.actions,
    required this.enabled,
    this.createdAt,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    final rawConditions = json['conditions'];
    final rawActions = json['actions'];
    return AutomationRule(
      id: json['id'],
      userId: json['userId'],
      name: json['name'],
      description: json['description'],
      trigger: Map<String, dynamic>.from(json['trigger'] ?? const {}),
      conditions: (rawConditions is List ? rawConditions : const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      actions: (rawActions is List ? rawActions : const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      enabled: json['enabled'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'name': name,
      'description': description,
      'trigger': trigger,
      'conditions': conditions,
      'actions': actions,
      'enabled': enabled,
    };
  }
}

