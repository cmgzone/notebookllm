class PluginCatalogItem {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final String entrypoint;
  final String version;
  final String? author;
  final List<String> tags;

  PluginCatalogItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.entrypoint,
    required this.version,
    required this.author,
    required this.tags,
  });

  factory PluginCatalogItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return PluginCatalogItem(
      id: json['id'],
      slug: json['slug'],
      name: json['name'],
      description: json['description'],
      entrypoint: json['entrypoint'] ?? 'run',
      version: json['version'] ?? '1.0.0',
      author: json['author'],
      tags: (rawTags is List ? rawTags : const []).map((e) => '$e').toList(),
    );
  }
}

