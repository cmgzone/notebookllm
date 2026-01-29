class FileAuditLog {
  final String id;
  final String action;
  final String path;
  final bool success;
  final String? errorMessage;
  final DateTime createdAt;

  FileAuditLog({
    required this.id,
    required this.action,
    required this.path,
    required this.success,
    required this.errorMessage,
    required this.createdAt,
  });

  factory FileAuditLog.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    return FileAuditLog(
      id: json['id'] as String,
      action: json['action'] as String,
      path: json['path'] as String,
      success: (json['success'] as bool?) ?? false,
      errorMessage: json['error_message'] as String?,
      createdAt: createdAtRaw is String ? DateTime.parse(createdAtRaw) : DateTime.now(),
    );
  }
}

