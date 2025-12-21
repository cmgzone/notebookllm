class Tag {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;

  Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#3B82F6',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
