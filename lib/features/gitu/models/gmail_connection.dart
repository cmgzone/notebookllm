class GmailConnectionInfo {
  final String? email;
  final String? scopes;
  final DateTime? connectedAt;
  final DateTime? lastUsedAt;

  GmailConnectionInfo({
    this.email,
    this.scopes,
    this.connectedAt,
    this.lastUsedAt,
  });

  factory GmailConnectionInfo.fromJson(Map<String, dynamic> json) {
    return GmailConnectionInfo(
      email: json['email'] as String?,
      scopes: json['scopes'] as String?,
      connectedAt: json['connectedAt'] != null ? DateTime.tryParse(json['connectedAt'] as String) : null,
      lastUsedAt: json['lastUsedAt'] != null ? DateTime.tryParse(json['lastUsedAt'] as String) : null,
    );
  }
}

class GmailStatus {
  final bool connected;
  final GmailConnectionInfo? connection;

  GmailStatus({
    required this.connected,
    this.connection,
  });

  factory GmailStatus.fromJson(Map<String, dynamic> json) {
    return GmailStatus(
      connected: (json['connected'] as bool?) ?? false,
      connection: json['connection'] != null
          ? GmailConnectionInfo.fromJson(json['connection'] as Map<String, dynamic>)
          : null,
    );
  }
}
