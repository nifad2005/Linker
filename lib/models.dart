import 'dart:async';

final StreamController<String> messageUpdates = StreamController<String>.broadcast();

class UserProfile {
  String name;
  final String id;
  String? profileImageUrl;

  UserProfile({required this.name, required this.id, this.profileImageUrl});

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'profileImageUrl': profileImageUrl,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? 'Unknown',
    id: json['id'] ?? '',
    profileImageUrl: json['profileImageUrl'],
  );
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final bool isSystem;
  bool isSeen;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.isSystem = false,
    this.isSeen = false,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isMe': isMe,
    'timestamp': timestamp.toIso8601String(),
    'isSystem': isSystem,
    'isSeen': isSeen,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] ?? '',
    isMe: json['isMe'] ?? false,
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    isSystem: json['isSystem'] ?? false,
    isSeen: json['isSeen'] ?? false,
  );
}

class ChatUser {
  String name;
  final String id;
  String? profileImageUrl;
  final List<ChatMessage> messages;
  bool isTyping;
  bool isOnline;
  int unreadCount;

  ChatUser({
    required this.name,
    required this.id,
    this.profileImageUrl,
    List<ChatMessage>? messages,
    this.isTyping = false,
    this.isOnline = false,
    int? unreadCount,
  }) : this.messages = messages ?? [],
       this.unreadCount = unreadCount ?? 0;

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'profileImageUrl': profileImageUrl,
    'messages': messages.map((m) => m.toJson()).toList(),
    'unreadCount': unreadCount,
  };

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      name: json['name'] ?? 'Unknown',
      id: json['id'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      messages: (json['messages'] as List?)?.map((m) => ChatMessage.fromJson(m)).toList() ?? [],
      unreadCount: json['unreadCount'] is int ? json['unreadCount'] : 0,
    );
  }
}
