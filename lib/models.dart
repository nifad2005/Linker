import 'dart:async';

class UserProfile {
  String name;
  String id;

  UserProfile({required this.name, required this.id});

  Map<String, dynamic> toJson() => {'name': name, 'id': id};
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(name: json['name'], id: json['id']);
}

class ChatMessage {
  final String id;
  String text;
  final bool isMe;
  final DateTime timestamp;
  bool isSeen;
  bool isDeleted;
  final bool isSystem;
  final Map<String, List<String>> reactions; // emoji -> list of userIds

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.isSeen = false,
    this.isDeleted = false,
    this.isSystem = false,
    Map<String, List<String>>? reactions,
  }) : reactions = reactions ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isMe': isMe,
    'timestamp': timestamp.toIso8601String(),
    'isSeen': isSeen,
    'isDeleted': isDeleted,
    'isSystem': isSystem,
    'reactions': reactions,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    text: json['text'],
    isMe: json['isMe'],
    timestamp: DateTime.parse(json['timestamp']).toLocal(),
    isSeen: json['isSeen'] ?? false,
    isDeleted: json['isDeleted'] ?? false,
    isSystem: json['isSystem'] ?? false,
    reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, List<String>.from(v)),
    ),
  );
}

class ChatUser {
  String name;
  final String id;
  bool isOnline;
  bool isTyping;
  int unreadCount;
  List<ChatMessage> messages;

  ChatUser({
    required this.name,
    required this.id,
    this.isOnline = false,
    this.isTyping = false,
    this.unreadCount = 0,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    name: json['name'],
    id: json['id'],
    messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
  );
}

final StreamController<String> messageUpdates = StreamController<String>.broadcast();
