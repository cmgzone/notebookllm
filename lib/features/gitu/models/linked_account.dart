class LinkedAccount {
  final String userId;
  final String platform;
  final String platformUserId;
  final String? displayName;
  final DateTime? linkedAt;
  final DateTime? lastUsedAt;
  final bool verified;
  final bool isPrimary;

  LinkedAccount({
    required this.userId,
    required this.platform,
    required this.platformUserId,
    this.displayName,
    this.linkedAt,
    this.lastUsedAt,
    this.verified = false,
    this.isPrimary = false,
  });

  factory LinkedAccount.fromJson(Map<String, dynamic> json) {
    return LinkedAccount(
      userId: json['user_id'] as String,
      platform: json['platform'] as String,
      platformUserId: json['platform_user_id'] as String,
      displayName: json['display_name'] as String?,
      linkedAt: json['linked_at'] != null ? DateTime.parse(json['linked_at']) : null,
      lastUsedAt: json['last_used_at'] != null ? DateTime.parse(json['last_used_at']) : null,
      verified: (json['verified'] as bool?) ?? false,
      isPrimary: (json['is_primary'] as bool?) ?? false,
    );
  }
}
