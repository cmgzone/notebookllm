class StudyGroup {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final String? ownerUsername;
  final String icon;
  final String? coverImageUrl;
  final bool isPublic;
  final int maxMembers;
  final int memberCount;
  final String? userRole;
  final DateTime createdAt;

  StudyGroup({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    this.ownerUsername,
    this.icon = '📚',
    this.coverImageUrl,
    this.isPublic = false,
    this.maxMembers = 50,
    this.memberCount = 1,
    this.userRole,
    required this.createdAt,
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    return StudyGroup(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      ownerId: json['owner_id'] ?? json['ownerId'],
      ownerUsername: json['owner_username'] ?? json['ownerUsername'],
      icon: json['icon'] ?? '📚',
      coverImageUrl: json['cover_image_url'] ?? json['coverImageUrl'],
      isPublic: json['is_public'] ?? json['isPublic'] ?? false,
      maxMembers: json['max_members'] ?? json['maxMembers'] ?? 50,
      memberCount: json['member_count'] ?? json['memberCount'] ?? 1,
      userRole: json['user_role'] ?? json['userRole'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }

  bool get isOwner => userRole == 'owner';
  bool get isAdmin => userRole == 'admin' || userRole == 'owner';
}

class GroupMember {
  final String id;
  final String groupId;
  final String userId;
  final String username;
  final String? email; // Made optional for privacy
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.username,
    this.email,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'],
      groupId: json['group_id'] ?? json['groupId'],
      userId: json['user_id'] ?? json['userId'],
      username: json['username'],
      email: json['email'], // Optional
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      role: json['role'] ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] ?? json['joinedAt']),
    );
  }
}

class StudySession {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? meetingUrl;
  final String createdBy;
  final String? createdByUsername;
  final DateTime createdAt;

  StudySession({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.meetingUrl,
    required this.createdBy,
    this.createdByUsername,
    required this.createdAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'],
      groupId: json['group_id'] ?? json['groupId'],
      title: json['title'],
      description: json['description'],
      scheduledAt: DateTime.parse(json['scheduled_at'] ?? json['scheduledAt']),
      durationMinutes:
          json['duration_minutes'] ?? json['durationMinutes'] ?? 60,
      meetingUrl: json['meeting_url'] ?? json['meetingUrl'],
      createdBy: json['created_by'] ?? json['createdBy'],
      createdByUsername:
          json['created_by_username'] ?? json['createdByUsername'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }

  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());
}

class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String groupIcon;
  final String invitedByUsername;
  final DateTime createdAt;

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
    required this.invitedByUsername,
    required this.createdAt,
  });

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: json['id'],
      groupId: json['group_id'] ?? json['groupId'],
      groupName: json['group_name'] ?? json['groupName'],
      groupIcon: json['group_icon'] ?? json['groupIcon'] ?? '📚',
      invitedByUsername:
          json['invited_by_username'] ?? json['invitedByUsername'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }
}
