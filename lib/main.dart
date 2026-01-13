import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models.dart';
import 'screens/chat_list_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
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

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isLoading = true;
  MqttServerClient? _client;
  bool _isConnected = false;
  AppLifecycleState _appState = AppLifecycleState.resumed;
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  UserProfile _currentUser = UserProfile(
    name: 'User-${const Uuid().v4().substring(0, 4)}',
    id: const Uuid().v4().substring(0, 8).toUpperCase(),
  );

  List<ChatUser> _users = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appState = state;
    if (state == AppLifecycleState.resumed) {
      _broadcastStatus(true);
    }
  }

  Future<void> _initApp() async {
    await _loadData();
    await _setupNotifications();
    await _setupMqtt();
  }

  Future<void> _setupNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);

    // Request permission for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'linker_messages',
      'Messages',
      description: 'Incoming messages from Linker',
      importance: Importance.max,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'linker_messages',
      'Messages',
      channelDescription: 'Incoming messages from Linker',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      DateTime.now().millisecond, // Unique ID for each notification
      title, 
      body, 
      details
    );
  }

  Future<void> _setupMqtt() async {
    _client = MqttServerClient('test.mosquitto.org', '');
    _client!.port = 1883;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;
    _client!.autoReconnect = true;
    
    _client!.onDisconnected = () {
      if (mounted) {
        Future.microtask(() => setState(() => _isConnected = false));
      }
    };
    _client!.onConnected = () {
      if (mounted) {
        Future.microtask(() {
          setState(() => _isConnected = true);
          _broadcastStatus(true);
        });
      }
    };
    
    final lwtPayload = jsonEncode({
      'type': 'STATUS',
      'senderId': _currentUser.id,
      'online': false,
    });

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('linker_${_currentUser.id}_${const Uuid().v4().substring(0, 4)}')
        .startClean()
        .withWillTopic('linker/status/${_currentUser.id}')
        .withWillMessage(lwtPayload)
        .withWillQos(MqttQos.atLeastOnce);
    
    try {
      (connMessage as dynamic).withWillRetain();
    } catch (_) {}
        
    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
      _client!.subscribe('linker/${_currentUser.id}', MqttQos.atLeastOnce);
      for (var user in _users) {
        _client!.subscribe('linker/status/${user.id}', MqttQos.atLeastOnce);
      }

      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        if (pt.isNotEmpty) {
          _handleIncomingMessage(pt);
        }
      });
    } catch (e) {
      debugPrint('MQTT connection failed: $e');
    }
  }

  void _broadcastStatus(bool online) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) return;
    final payload = jsonEncode({
      'type': 'STATUS',
      'senderId': _currentUser.id,
      'online': online,
      'senderName': _currentUser.name,
      'profileImageUrl': _currentUser.profileImageUrl,
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage('linker/status/${_currentUser.id}', MqttQos.atLeastOnce, builder.payload!, retain: true);
  }

  void _handleIncomingMessage(String payload) {
    if (payload.trim().isEmpty) return;
    try {
      final dynamic decoded = jsonDecode(payload);
      if (decoded is! Map) return;

      final String? senderId = decoded['senderId'];
      if (senderId == null || senderId == _currentUser.id) return;

      final String type = decoded['type'] ?? 'MESSAGE';
      final String senderName = decoded['senderName'] ?? 'Peer-$senderId';
      final String? profileImageUrl = decoded['profileImageUrl'];
      final String text = decoded['text'] ?? '';

      if (mounted) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            int index = _users.indexWhere((u) => u.id == senderId);
            if (index == -1) {
              _users.insert(0, ChatUser(
                name: senderName, 
                id: senderId, 
                profileImageUrl: profileImageUrl,
                messages: []
              ));
              index = 0;
              _client?.subscribe('linker/status/$senderId', MqttQos.atLeastOnce);
              if (type == 'CONNECT') {
                 _sendHandshake(senderId, isResponse: true);
              }
            } else {
              _users[index].name = senderName;
              if (profileImageUrl != null) {
                _users[index].profileImageUrl = profileImageUrl;
              }
            }

            if (type == 'STATUS') {
              _users[index].isOnline = decoded['online'] ?? false;
              _users[index].name = decoded['senderName'] ?? _users[index].name;
              _users[index].profileImageUrl = decoded['profileImageUrl'] ?? _users[index].profileImageUrl;
            } else if (type == 'TYPING') {
              _users[index].isTyping = decoded['isTyping'] ?? false;
            } else if (type == 'SEEN') {
              for (var msg in _users[index].messages) {
                if (msg.isMe) msg.isSeen = true;
              }
            } else if (type == 'CONNECT') {
              _users[index].messages.insert(0, ChatMessage(
                text: 'Connection established with $senderName',
                isMe: false,
                timestamp: DateTime.now(),
                isSystem: true,
              ));
              _broadcastStatus(true);
            } else if (type == 'MESSAGE') {
              _users[index].isTyping = false;
              _users[index].messages.insert(0, ChatMessage(
                text: text,
                isMe: false,
                timestamp: DateTime.now(),
              ));
              _users[index].unreadCount++;

              // Show notification if app is in background
              if (_appState != AppLifecycleState.resumed) {
                _showNotification(senderName, text);
              }
            }
          });
          messageUpdates.add(senderId);
          _saveData();
        });
      }
    } catch (e) {
      debugPrint('Error handling message: $e Payload: "$payload"');
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_profile');
      if (userJson != null && userJson.isNotEmpty) {
        _currentUser = UserProfile.fromJson(jsonDecode(userJson));
      } else {
        await prefs.setString('user_profile', jsonEncode(_currentUser.toJson()));
      }
      final connectionsJson = prefs.getString('connections');
      if (connectionsJson != null && connectionsJson.isNotEmpty) {
        final List decoded = jsonDecode(connectionsJson);
        final List<ChatUser> loadedUsers = decoded.map((u) => ChatUser.fromJson(u)).toList();
        if (mounted) {
          Future.microtask(() {
            setState(() {
               _users = loadedUsers;
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        Future.microtask(() => setState(() => _isLoading = false));
      }
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
    
    _client?.subscribe('linker/status/$peerId', MqttQos.atLeastOnce);
    _sendHandshake(peerId);
    _saveData();
  }

  void deleteConnection(String peerId) {
    setState(() {
      _users.removeWhere((u) => u.id == peerId);
    });
    _client?.unsubscribe('linker/status/$peerId');
    _saveData();
  }

  void clearUnread(String peerId) {
    if (mounted) {
      Future.microtask(() {
        setState(() {
          int index = _users.indexWhere((u) => u.id == peerId);
          if (index != -1) {
            _users[index].unreadCount = 0;
          }
        });
        _saveData();
      });
    }
  }

  void _sendHandshake(String peerId, {bool isResponse = false}) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) return;

    final payload = jsonEncode({
      'type': 'CONNECT',
      'senderId': _currentUser.id,
      'senderName': _currentUser.name,
      'profileImageUrl': _currentUser.profileImageUrl,
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
      'profileImageUrl': _currentUser.profileImageUrl,
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

  void sendTypingStatus(String peerId, bool isTyping) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) return;
    final payload = jsonEncode({
      'type': 'TYPING',
      'senderId': _currentUser.id,
      'isTyping': isTyping,
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage('linker/$peerId', MqttQos.atMostOnce, builder.payload!);
  }

  void sendSeenStatus(String peerId) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) return;
    final payload = jsonEncode({
      'type': 'SEEN',
      'senderId': _currentUser.id,
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage('linker/$peerId', MqttQos.atLeastOnce, builder.payload!);
    
    // Also clear locally
    clearUnread(peerId);
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
              onSendTyping: sendTypingStatus,
              onSendSeen: sendSeenStatus,
              onClearUnread: clearUnread,
              myId: _currentUser.id, 
              isConnected: _isConnected
            )
          : ProfileScreen(
              user: _currentUser, 
              onUpdateName: (name) { setState(() => _currentUser.name = name); _saveData(); _broadcastStatus(true); },
              onUpdateImage: (path) { setState(() => _currentUser.profileImageUrl = path); _saveData(); _broadcastStatus(true); },
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
