class FilePermissionsStatus {
  final bool active;
  final List<String> allowedPaths;
  final List<String> actions;
  final DateTime? expiresAt;

  FilePermissionsStatus({
    required this.active,
    required this.allowedPaths,
    required this.actions,
    required this.expiresAt,
  });

  factory FilePermissionsStatus.fromJson(Map<String, dynamic> json) {
    final allowed = (json['allowedPaths'] as List?)?.whereType<String>().toList() ?? const [];
    final actions = (json['actions'] as List?)?.whereType<String>().toList() ?? const [];
    final expiresAtRaw = json['expiresAt'];
    return FilePermissionsStatus(
      active: (json['active'] as bool?) ?? false,
      allowedPaths: allowed,
      actions: actions,
      expiresAt: expiresAtRaw is String ? DateTime.tryParse(expiresAtRaw) : null,
    );
  }
}

