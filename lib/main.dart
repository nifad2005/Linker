import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LinkerApp());
}

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

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isMe': isMe,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'],
    isMe: json['isMe'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class ChatUser {
  final String name;
  final String lastMessage;
  final String time;
  final String id;
  final List<ChatMessage> messages;

  ChatUser({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.id,
    this.messages = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'lastMessage': lastMessage,
    'time': time,
    'id': id,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    name: json['name'],
    lastMessage: json['lastMessage'],
    time: json['time'],
    id: json['id'],
    messages: (json['messages'] as List?)?.map((m) => ChatMessage.fromJson(m)).toList() ?? [],
  );
}

class LinkerApp extends StatelessWidget {
  const LinkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color(0xFF242424),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  
  UserProfile _currentUser = UserProfile(
    name: 'John Doe',
    id: 'LNK-7729-XQ',
    profileImageUrl: null,
  );

  List<ChatUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_profile');
      if (userJson != null) {
        _currentUser = UserProfile.fromJson(jsonDecode(userJson));
      }
      final connectionsJson = prefs.getString('connections');
      if (connectionsJson != null) {
        final List decoded = jsonDecode(connectionsJson);
        _users = decoded.map((u) => ChatUser.fromJson(u)).toList();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(_currentUser.toJson()));
    await prefs.setString('connections', jsonEncode(_users.map((u) => u.toJson()).toList()));
  }

  void _addNewConnection(String linkerId) {
    final Map<String, String> _globalDirectory = {
      'LNK-1234-AB': 'Sarah Wilson',
      'LNK-5678-CD': 'Mike Ross',
    };

    if (_globalDirectory.containsKey(linkerId)) {
      final userName = _globalDirectory[linkerId]!;
      if (_users.any((u) => u.id == linkerId)) return;
      setState(() {
        _users.insert(0, ChatUser(
          name: userName,
          lastMessage: 'Connected!',
          time: 'Just now',
          id: linkerId,
        ));
      });
      _saveData();
    }
  }

  void _addMessage(String userId, ChatMessage message) {
    setState(() {
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index].messages.insert(0, message);
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: _selectedIndex == 0 
          ? ChatListScreen(users: _users, onAddConnection: _addNewConnection, myId: _currentUser.id)
          : ProfileScreen(
              user: _currentUser, 
              onUpdateName: (name) { setState(() => _currentUser.name = name); _saveData(); },
              onUpdateImage: (path) { setState(() => _currentUser.profileImageUrl = path); _saveData(); },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class ChatListScreen extends StatelessWidget {
  final List<ChatUser> users;
  final Function(String) onAddConnection;
  final String myId;

  const ChatListScreen({super.key, required this.users, required this.onAddConnection, required this.myId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF242424),
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.qr_code_scanner),
                      title: const Text('Scan QR Code'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => QRScannerScreen(onScan: onAddConnection)));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.qr_code),
                      title: const Text('My QR Code'),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF242424),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('My Linker ID'),
                                const SizedBox(height: 20),
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: QrImageView(data: myId, version: QrVersions.auto),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(myId, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: users.isEmpty
          ? const Center(child: Text('No connections', style: TextStyle(color: Colors.white24)))
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user.name),
                  subtitle: Text(user.messages.isNotEmpty ? user.messages.first.text : user.lastMessage),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MessagePage(
                    user: user,
                    onMessageSent: (msg) => context.findAncestorStateOfType<_MainScreenState>()?._addMessage(user.id, msg),
                  ))),
                );
              },
            ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final Function(String) onScan;
  const QRScannerScreen({super.key, required this.onScan});
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _scanned = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: MobileScanner(onDetect: (cap) {
        if (_scanned) return;
        final code = cap.barcodes.first.rawValue;
        if (code != null) {
          setState(() => _scanned = true);
          widget.onScan(code);
          Navigator.pop(context);
        }
      }),
    );
  }
}

class MessagePage extends StatefulWidget {
  final ChatUser user;
  final Function(ChatMessage) onMessageSent;
  const MessagePage({super.key, required this.user, required this.onMessageSent});
  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.user.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: widget.user.messages.length,
              itemBuilder: (context, index) {
                final m = widget.user.messages[index];
                return Align(
                  alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: m.isMe ? Colors.white10 : const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Message'))),
                IconButton(icon: const Icon(Icons.send), onPressed: () {
                  if (_ctrl.text.isEmpty) return;
                  final msg = ChatMessage(text: _ctrl.text, isMe: true, timestamp: DateTime.now());
                  widget.onMessageSent(msg);
                  setState(() => widget.user.messages.insert(0, msg));
                  _ctrl.clear();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final UserProfile user;
  final Function(String) onUpdateName;
  final Function(String) onUpdateImage;
  const ProfileScreen({super.key, required this.user, required this.onUpdateName, required this.onUpdateImage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 80),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(radius: 60, backgroundImage: user.profileImageUrl != null ? FileImage(File(user.profileImageUrl!)) : null, child: user.profileImageUrl == null ? const Icon(Icons.person, size: 60) : null),
                  IconButton(icon: const Icon(Icons.camera_alt), onPressed: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (img != null) onUpdateImage(img.path);
                  }),
                ],
              ),
              const SizedBox(height: 20),
              Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(user.id, style: const TextStyle(color: Colors.white38)),
              const SizedBox(height: 40),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Name'),
                onTap: () {
                  final c = TextEditingController(text: user.name);
                  showDialog(context: context, builder: (context) => AlertDialog(
                    title: const Text('Edit Name'),
                    content: TextField(controller: c),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () { onUpdateName(c.text); Navigator.pop(context); }, child: const Text('Save'))],
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
