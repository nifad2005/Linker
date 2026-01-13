import 'dart:async';

final StreamController<String> messageUpdates = StreamController<String>.broadcast();

class UserProfile {
  String name;
  final String id;

  UserProfile({required this.name, required this.id});

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? 'Unknown',
    id: json['id'] ?? '',
  );
}

class ChatMessage {
  final String id;
  String text;
  final bool isMe;
  final DateTime timestamp;
  final bool isSystem;
  bool isSeen;
  bool isDeleted;
  Map<String, List<String>> reactions; // emoji -> list of userIds

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.isSystem = false,
    this.isSeen = false,
    this.isDeleted = false,
    Map<String, List<String>>? reactions,
  }) : this.reactions = reactions ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isMe': isMe,
    'timestamp': timestamp.toIso8601String(),
    'isSystem': isSystem,
    'isSeen': isSeen,
    'isDeleted': isDeleted,
    'reactions': reactions,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] ?? '',
    text: json['text'] ?? '',
    isMe: json['isMe'] ?? false,
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    isSystem: json['isSystem'] ?? false,
    isSeen: json['isSeen'] ?? false,
    isDeleted: json['isDeleted'] ?? false,
    reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, List<String>.from(v)),
    ),
  );
}

class ChatUser {
  String name;
  final String id;
  final List<ChatMessage> messages;
  bool isTyping;
  bool isOnline;
  int unreadCount;

  ChatUser({
    required this.name,
    required this.id,
    List<ChatMessage>? messages,
    this.isTyping = false,
    this.isOnline = false,
    int? unreadCount,
  }) : this.messages = messages ?? [],
       this.unreadCount = unreadCount ?? 0;

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'messages': messages.map((m) => m.toJson()).toList(),
    'unreadCount': unreadCount,
  };

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      name: json['name'] ?? 'Unknown',
      id: json['id'] ?? '',
      messages: (json['messages'] as List?)?.map((m) => ChatMessage.fromJson(m)).toList() ?? [],
      unreadCount: json['unreadCount'] is int ? json['unreadCount'] : 0,
    );
  }
}
