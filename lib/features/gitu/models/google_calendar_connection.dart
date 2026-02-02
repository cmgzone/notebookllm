class GoogleCalendarConnectionInfo {
  final String? email;
  final String? scopes;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  GoogleCalendarConnectionInfo({
    this.email,
    this.scopes,
    this.createdAt,
    this.lastUsedAt,
  });

  factory GoogleCalendarConnectionInfo.fromJson(Map<String, dynamic> json) {
    return GoogleCalendarConnectionInfo(
      email: json['email'] as String?,
      scopes: json['scopes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
    );
  }
}

class GoogleCalendarStatus {
  final bool connected;
  final GoogleCalendarConnectionInfo? connection;

  GoogleCalendarStatus({
    required this.connected,
    this.connection,
  });

  factory GoogleCalendarStatus.fromJson(Map<String, dynamic> json) {
    return GoogleCalendarStatus(
      connected: (json['connected'] as bool?) ?? false,
      connection: json['connection'] != null
          ? GoogleCalendarConnectionInfo.fromJson(
              json['connection'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

