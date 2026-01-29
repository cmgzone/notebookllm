class GituPermission {
  final String id;
  final String resource;
  final List<String> actions;
  final Map<String, dynamic>? scope;
  final DateTime? grantedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  const GituPermission({
    required this.id,
    required this.resource,
    required this.actions,
    required this.scope,
    required this.grantedAt,
    required this.expiresAt,
    required this.revokedAt,
  });

  bool get isActive {
    if (revokedAt != null) return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  factory GituPermission.fromJson(Map<String, dynamic> json) {
    final scopeRaw = json['scope'];
    return GituPermission(
      id: (json['id'] as String?) ?? '',
      resource: (json['resource'] as String?) ?? '',
      actions: (json['actions'] as List?)?.whereType<String>().toList() ?? const [],
      scope: scopeRaw is Map<String, dynamic> ? scopeRaw : scopeRaw is Map ? Map<String, dynamic>.from(scopeRaw) : null,
      grantedAt: json['grantedAt'] is String ? DateTime.tryParse(json['grantedAt'] as String) : null,
      expiresAt: json['expiresAt'] is String ? DateTime.tryParse(json['expiresAt'] as String) : null,
      revokedAt: json['revokedAt'] is String ? DateTime.tryParse(json['revokedAt'] as String) : null,
    );
  }
}

