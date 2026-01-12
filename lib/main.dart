import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

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

class LinkerApp extends StatelessWidget {
  const LinkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.blueAccent,
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
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
  MqttServerClient? _client;
  bool _isConnected = false;
  
  UserProfile _currentUser = UserProfile(
    name: 'User-${const Uuid().v4().substring(0, 4)}',
    id: const Uuid().v4().substring(0, 8).toUpperCase(),
  );

  List<ChatUser> _users = [];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _loadData();
    await _setupMqtt();
  }

  Future<void> _setupMqtt() async {
    _client = MqttServerClient('test.mosquitto.org', '');
    _client!.port = 1883;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = () {
      if (mounted) setState(() => _isConnected = false);
    };
    _client!.onConnected = () {
      if (mounted) setState(() => _isConnected = true);
    };
    
    final connMessage = MqttConnectMessage()
        .withClientIdentifier('linker_${_currentUser.id}_${const Uuid().v4().substring(0, 4)}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
      _client!.subscribe('linker/${_currentUser.id}', MqttQos.atLeastOnce);
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        _handleIncomingMessage(pt);
      });
    } catch (e) {
      debugPrint('MQTT connection failed: $e');
    }
  }

  void _handleIncomingMessage(String payload) {
    try {
      final decoded = jsonDecode(payload);
      final String type = decoded['type'] ?? 'MESSAGE';
      final String senderId = decoded['senderId'];
      final String senderName = decoded['senderName'] ?? 'Peer-$senderId';
      final String text = decoded['text'] ?? '';

      if (mounted) {
        setState(() {
          int index = _users.indexWhere((u) => u.id == senderId);
          if (index == -1) {
            _users.insert(0, ChatUser(name: senderName, id: senderId, messages: []));
            index = 0;
            if (type == 'CONNECT') {
               _sendHandshake(senderId, isResponse: true);
            }
          } else {
            _users[index].name = senderName;
          }

          if (type == 'CONNECT') {
            _users[index].messages.insert(0, ChatMessage(
              text: 'Connection established with $senderName',
              isMe: false,
              timestamp: DateTime.now(),
              isSystem: true,
            ));
          } else {
            _users[index].messages.insert(0, ChatMessage(
              text: text,
              isMe: false,
              timestamp: DateTime.now(),
            ));
          }
        });
        _saveData();
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_profile');
      if (userJson != null) {
        _currentUser = UserProfile.fromJson(jsonDecode(userJson));
      } else {
        await prefs.setString('user_profile', jsonEncode(_currentUser.toJson()));
      }
      final connectionsJson = prefs.getString('connections');
      if (connectionsJson != null) {
        final List decoded = jsonDecode(connectionsJson);
        setState(() {
           _users = decoded.map((u) => ChatUser.fromJson(u)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(_currentUser.toJson()));
    await prefs.setString('connections', jsonEncode(_users.map((u) => u.toJson()).toList()));
  }

  void _addNewConnection(String peerId) {
    if (peerId == _currentUser.id) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't link to yourself!")));
       return;
    }
    
    if (_users.any((u) => u.id == peerId)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Already linked!")));
       return;
    }

    setState(() {
      _users.insert(0, ChatUser(
        name: 'Connecting...',
        id: peerId,
        messages: [
          ChatMessage(text: 'Requesting connection...', isMe: true, timestamp: DateTime.now(), isSystem: true)
        ],
      ));
    });
    
    _sendHandshake(peerId);
    _saveData();
  }

  void _sendHandshake(String peerId, {bool isResponse = false}) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) return;

    final payload = jsonEncode({
      'type': 'CONNECT',
      'senderId': _currentUser.id,
      'senderName': _currentUser.name,
      'text': isResponse ? 'Accepted connection' : 'Requested connection',
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage('linker/$peerId', MqttQos.atLeastOnce, builder.payload!);
  }

  void _sendMessage(String peerId, String text) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not connected to global network")));
       return;
    }

    final payload = jsonEncode({
      'type': 'MESSAGE',
      'senderId': _currentUser.id,
      'senderName': _currentUser.name,
      'text': text,
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage('linker/$peerId', MqttQos.atLeastOnce, builder.payload!);

    setState(() {
      int index = _users.indexWhere((u) => u.id == peerId);
      if (index != -1) {
        _users[index].messages.insert(0, ChatMessage(text: text, isMe: true, timestamp: DateTime.now()));
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: _selectedIndex == 0 
          ? ChatListScreen(users: _users, onAddConnection: _addNewConnection, myId: _currentUser.id, isConnected: _isConnected)
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
        backgroundColor: const Color(0xFF1E1E1E),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class ChatListScreen extends StatelessWidget {
  final List<ChatUser> users;
  final Function(String) onAddConnection;
  final String myId;
  final bool isConnected;

  const ChatListScreen({super.key, required this.users, required this.onAddConnection, required this.myId, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Links', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: () => _showAddMenu(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  const Text('No global links yet', style: TextStyle(color: Colors.white38, fontSize: 16)),
                  TextButton(onPressed: () => _showAddMenu(context), child: const Text('Add Connection')),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final lastMsg = user.messages.isNotEmpty ? user.messages.first : null;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    child: Text(user.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                  subtitle: lastMsg != null 
                    ? Text(
                        lastMsg.text, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis, 
                        style: TextStyle(color: lastMsg.isSystem ? Colors.blueAccent : Colors.white38)
                      )
                    : const Text('New connection', style: TextStyle(color: Colors.white38)),
                  trailing: lastMsg != null 
                    ? Text(DateFormat('HH:mm').format(lastMsg.timestamp), style: const TextStyle(fontSize: 12, color: Colors.white24))
                    : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MessagePage(
                    user: user,
                    onMessageSent: (text) => context.findAncestorStateOfType<_MainScreenState>()?._sendMessage(user.id, text),
                  ))),
                );
              },
            ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan QR Code'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, MaterialPageRoute(builder: (context) => QRScannerScreen(onScan: onAddConnection)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('My Global ID'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, MaterialPageRoute(builder: (context) => MyIdPage(myId: myId)));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class MyIdPage extends StatelessWidget {
  final String myId;
  const MyIdPage({super.key, required this.myId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Linker ID')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: myId,
                version: QrVersions.auto,
                size: 240,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
            const SizedBox(height: 40),
            Text(myId, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6)),
            const SizedBox(height: 12),
            const Text('Anyone can scan this globally', style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class MessagePage extends StatefulWidget {
  final ChatUser user;
  final Function(String) onMessageSent;
  const MessagePage({super.key, required this.user, required this.onMessageSent});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    if (_ctrl.text.trim().isEmpty) return;
    widget.onMessageSent(_ctrl.text.trim());
    _ctrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.05),
              child: Text(widget.user.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.user.name, style: const TextStyle(fontSize: 18))),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: widget.user.messages.length,
              itemBuilder: (context, index) {
                final m = widget.user.messages[index];
                if (m.isSystem) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: Text(m.text, style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                    ),
                  );
                }
                return Align(
                  alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: m.isMe ? Colors.white.withOpacity(0.1) : const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(m.isMe ? 16 : 0),
                            bottomRight: Radius.circular(m.isMe ? 0 : 16),
                          ),
                        ),
                        child: Text(m.text, style: const TextStyle(fontSize: 16)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(DateFormat('HH:mm').format(m.timestamp), style: const TextStyle(fontSize: 10, color: Colors.white12)),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _sendMessage,
                ),
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
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  backgroundImage: user.profileImageUrl != null ? FileImage(File(user.profileImageUrl!)) : null,
                  child: user.profileImageUrl == null ? const Icon(Icons.person, size: 64, color: Colors.white12) : null,
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                    onPressed: () async {
                      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (img != null) onUpdateImage(img.path);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildInfoCard(context, 'Name', user.name, Icons.edit_outlined, () => _showEditName(context)),
            const SizedBox(height: 16),
            _buildInfoCard(context, 'ID', user.id, Icons.copy_outlined, () {
              // Copy to clipboard or just show snackbar
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID copied to clipboard')));
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(icon, size: 20, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showEditName(BuildContext context) {
    final ctrl = TextEditingController(text: user.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Enter your name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onUpdateName(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
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
      body: MobileScanner(
        onDetect: (cap) {
          if (_scanned) return;
          final code = cap.barcodes.first.rawValue;
          if (code != null) {
            setState(() => _scanned = true);
            widget.onScan(code);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
