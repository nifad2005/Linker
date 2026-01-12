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
    name: json['name'],
    id: json['id'],
    profileImageUrl: json['profileImageUrl'],
  );
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final bool isSystem;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.isSystem = false,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isMe': isMe,
    'timestamp': timestamp.toIso8601String(),
    'isSystem': isSystem,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'],
    isMe: json['isMe'],
    timestamp: DateTime.parse(json['timestamp']),
    isSystem: json['isSystem'] ?? false,
  );
}

class ChatUser {
  String name;
  final String id;
  final List<ChatMessage> messages;

  ChatUser({
    required this.name,
    required this.id,
    this.messages = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    name: json['name'],
    id: json['id'],
    messages: (json['messages'] as List?)?.map((m) => ChatMessage.fromJson(m)).toList() ?? [],
  );
}
