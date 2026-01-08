class Friend {
  final String id;
  final String friendId;
  final String username;
  final String?
      email; // Made optional since backend doesn't return it for privacy
  final String? avatarUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  Friend({
    required this.id,
    required this.friendId,
    required this.username,
    this.email,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      friendId: json['friend_id'] ?? json['friendId'],
      username: json['username'],
      email: json['email'], // Optional
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      status: json['status'] ?? 'accepted',
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      acceptedAt: json['accepted_at'] != null || json['acceptedAt'] != null
          ? DateTime.parse(json['accepted_at'] ?? json['acceptedAt'])
          : null,
    );
  }
}

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String? fromEmail; // Made optional
  final String? fromAvatarUrl;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    this.fromEmail,
    this.fromAvatarUrl,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      fromUserId: json['from_user_id'] ?? json['fromUserId'],
      fromUsername: json['from_username'] ?? json['fromUsername'],
      fromEmail: json['from_email'] ?? json['fromEmail'], // Optional
      fromAvatarUrl: json['from_avatar_url'] ?? json['fromAvatarUrl'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }
}

class UserSearchResult {
  final String id;
  final String username;
  final String? email; // Made optional
  final String? avatarUrl;

  UserSearchResult({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'],
      username: json['username'],
      email: json['email'], // Optional
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
    );
  }
}
