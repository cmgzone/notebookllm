class CustomAgent {
  final String id;
  final String name;
  final String? description;
  final String systemPrompt;
  final List<String> skillIds;

  const CustomAgent({
    required this.id,
    required this.name,
    this.description,
    required this.systemPrompt,
    required this.skillIds,
  });

  factory CustomAgent.fromJson(Map<String, dynamic> json) {
    return CustomAgent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      systemPrompt: json['systemPrompt']?.toString() ?? '',
      skillIds: (json['skillIds'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
        'skillIds': skillIds,
      };
}
