class GituPlugin {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String code;
  final String entrypoint;
  final Map<String, dynamic> config;
  final String? sourceCatalogId;
  final String? sourceCatalogVersion;
  final bool enabled;
  final String type; // 'script' or 'mcp'
  final Map<String, dynamic> mcpConfig;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GituPlugin({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.code,
    required this.entrypoint,
    required this.config,
    required this.sourceCatalogId,
    required this.sourceCatalogVersion,
    required this.enabled,
    this.type = 'script',
    this.mcpConfig = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory GituPlugin.fromJson(Map<String, dynamic> json) {
    return GituPlugin(
      id: json['id'],
      userId: json['userId'],
      name: json['name'],
      description: json['description'],
      code: json['code'] ?? '',
      entrypoint: json['entrypoint'] ?? 'run',
      config: Map<String, dynamic>.from(json['config'] ?? const {}),
      sourceCatalogId: json['sourceCatalogId'],
      sourceCatalogVersion: json['sourceCatalogVersion'],
      enabled: json['enabled'] ?? true,
      type: json['type'] ?? 'script',
      mcpConfig: Map<String, dynamic>.from(json['mcp_config'] ?? const {}),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'name': name,
      'description': description,
      'code': code,
      'entrypoint': entrypoint,
      'config': config,
      'enabled': enabled,
      'type': type,
      'mcp_config': mcpConfig,
    };
  }
}
