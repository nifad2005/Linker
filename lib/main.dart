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
  MqttServerClient? _client;
  
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
    _client!.onDisconnected = () => debugPrint('MQTT Disconnected');
    
    final connMessage = MqttConnectMessage()
        .withClientIdentifier('linker_${_currentUser.id}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
      debugPrint('MQTT Connected');
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

      setState(() {
        int index = _users.indexWhere((u) => u.id == senderId);
        if (index == -1) {
          _users.insert(0, ChatUser(name: senderName, id: senderId, messages: []));
          index = 0;
          
          // If we received a connection request, send our info back
          if (type == 'CONNECT') {
             _sendHandshake(senderId, isResponse: true);
          }
        } else {
          // Update name if changed
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Links'),
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
                      title: const Text('Scan Global ID'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => QRScannerScreen(onScan: onAddConnection)));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.qr_code),
                      title: const Text('My Global ID'),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF242424),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Global Linker ID'),
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
                                Text(myId, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                                const Text('Anyone can scan this globally', style: TextStyle(fontSize: 10, color: Colors.white38)),
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
          ? const Center(child: Text('No global links.\nScan an ID to start!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white24)))
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final lastMsg = user.messages.isNotEmpty ? user.messages.first : null;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.public)),
                  title: Text(user.name),
                  subtitle: lastMsg != null 
                    ? Text(lastMsg.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: lastMsg.isSystem ? Colors.blueAccent : null))
                    : const Text('No messages yet'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MessagePage(
                    user: user,
                    onMessageSent: (text) => context.findAncestorStateOfType<_MainScreenState>()?._sendMessage(user.id, text),
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
  final Function(String) onMessageSent;
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
                if (m.isSystem) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(m.text, style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontStyle: FontStyle.italic)),
                    ),
                  );
                }
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
                Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Global Message'))),
                IconButton(icon: const Icon(Icons.send), onPressed: () {
                  if (_ctrl.text.isEmpty) return;
                  widget.onMessageSent(_ctrl.text);
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
              Text("Global ID: ${user.id}", style: const TextStyle(color: Colors.white38, letterSpacing: 2)),
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
