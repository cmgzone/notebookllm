class GituRequestedPermission {
  final String resource;
  final List<String> actions;
  final Map<String, dynamic>? scope;
  final DateTime? expiresAt;

  const GituRequestedPermission({
    required this.resource,
    required this.actions,
    required this.scope,
    required this.expiresAt,
  });

  factory GituRequestedPermission.fromJson(Map<String, dynamic> json) {
    final scopeRaw = json['scope'];
    return GituRequestedPermission(
      resource: (json['resource'] as String?) ?? '',
      actions: (json['actions'] as List?)?.whereType<String>().toList() ?? const [],
      scope: scopeRaw is Map<String, dynamic> ? scopeRaw : scopeRaw is Map ? Map<String, dynamic>.from(scopeRaw) : null,
      expiresAt: json['expiresAt'] is String ? DateTime.tryParse(json['expiresAt'] as String) : null,
    );
  }
}

class GituPermissionRequest {
  final String id;
  final GituRequestedPermission permission;
  final String reason;
  final String status;
  final DateTime? requestedAt;
  final DateTime? respondedAt;
  final String? grantedPermissionId;

  const GituPermissionRequest({
    required this.id,
    required this.permission,
    required this.reason,
    required this.status,
    required this.requestedAt,
    required this.respondedAt,
    required this.grantedPermissionId,
  });

  bool get isPending => status == 'pending';

  factory GituPermissionRequest.fromJson(Map<String, dynamic> json) {
    return GituPermissionRequest(
      id: (json['id'] as String?) ?? '',
      permission: GituRequestedPermission.fromJson(
        (json['permission'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
      reason: (json['reason'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      requestedAt: json['requestedAt'] is String ? DateTime.tryParse(json['requestedAt'] as String) : null,
      respondedAt: json['respondedAt'] is String ? DateTime.tryParse(json['respondedAt'] as String) : null,
      grantedPermissionId: json['grantedPermissionId'] as String?,
    );
  }
}

