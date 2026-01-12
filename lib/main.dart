import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'screens/chat_list_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LinkerApp());
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
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
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
    _client!.autoReconnect = true;
    
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
      final dynamic decoded = jsonDecode(payload);
      if (decoded is! Map) return;

      final String? senderId = decoded['senderId'];
      if (senderId == null || senderId == _currentUser.id) return;

      final String type = decoded['type'] ?? 'MESSAGE';
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
        messageUpdates.add(senderId);
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

  void addNewConnection(String peerId) {
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

  void deleteConnection(String peerId) {
    setState(() {
      _users.removeWhere((u) => u.id == peerId);
    });
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

  void sendMessage(String peerId, String text) {
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
    messageUpdates.add(peerId);
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: _selectedIndex == 0 
          ? ChatListScreen(
              users: _users, 
              onAddConnection: addNewConnection, 
              onDeleteConnection: deleteConnection,
              onSendMessage: sendMessage,
              myId: _currentUser.id, 
              isConnected: _isConnected
            )
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
