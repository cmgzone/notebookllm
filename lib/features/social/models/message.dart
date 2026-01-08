class Message {
  final String id;
  final String senderId;
  final String senderUsername;
  final String? senderAvatarUrl;
  final String content;
  final String messageType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    this.senderAvatarUrl,
    required this.content,
    this.messageType = 'text',
    this.metadata,
    required this.createdAt,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'],
      senderUsername: json['senderUsername'] ?? 'Unknown',
      senderAvatarUrl: json['senderAvatarUrl'],
      content: json['content'],
      messageType: json['messageType'] ?? 'text',
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
    );
  }
}

class GroupMessage extends Message {
  final String groupId;
  final String? replyToId;
  final String? replyToContent;

  GroupMessage({
    required super.id,
    required super.senderId,
    required super.senderUsername,
    super.senderAvatarUrl,
    required super.content,
    super.messageType,
    super.metadata,
    required super.createdAt,
    required this.groupId,
    this.replyToId,
    this.replyToContent,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: json['id'],
      senderId: json['senderId'],
      senderUsername: json['senderUsername'] ?? 'Unknown',
      senderAvatarUrl: json['senderAvatarUrl'],
      content: json['content'],
      messageType: json['messageType'] ?? 'text',
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['createdAt']),
      groupId: json['groupId'],
      replyToId: json['replyToId'],
      replyToContent: json['replyToContent'],
    );
  }
}

class Conversation {
  final String id;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      otherUserId: json['otherUserId'],
      otherUsername: json['otherUsername'] ?? 'Unknown',
      otherAvatarUrl: json['otherAvatarUrl'],
      lastMessage: json['lastMessage'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class UnreadCounts {
  final int direct;
  final int groups;

  UnreadCounts({this.direct = 0, this.groups = 0});

  int get total => direct + groups;

  factory UnreadCounts.fromJson(Map<String, dynamic> json) {
    return UnreadCounts(
      direct: json['direct'] ?? 0,
      groups: json['groups'] ?? 0,
    );
  }
}
