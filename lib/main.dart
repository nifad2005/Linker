import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const LinkerApp());
}

class UserProfile {
  String name;
  final String id;
  String? profileImageUrl;

  UserProfile({required this.name, required this.id, this.profileImageUrl});
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
}

class ChatUser {
  final String name;
  final String lastMessage;
  final String time;
  final String id;

  ChatUser({required this.name, required this.lastMessage, required this.time, required this.id});
}

class LinkerApp extends StatelessWidget {
  const LinkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFF1A1A1A);
    const Color surface = Color(0xFF242424);
    const Color primaryText = Color(0xFFD1D1D1);
    const Color secondaryText = Color(0xFF8E8E8E);

    return MaterialApp(
      title: 'Linker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primaryText,
          onPrimary: background,
          surface: surface,
          onSurface: primaryText,
          background: background,
          onBackground: primaryText,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: primaryText, size: 20),
          titleTextStyle: TextStyle(
            color: primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: background,
          selectedItemColor: primaryText,
          unselectedItemColor: secondaryText,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
          bodyLarge: TextStyle(color: primaryText, fontSize: 16),
          bodyMedium: TextStyle(color: primaryText, fontSize: 14),
        ),
        iconTheme: const IconThemeData(color: primaryText),
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
  
  UserProfile _currentUser = UserProfile(
    name: 'John Doe',
    id: 'LNK-7729-XQ',
    profileImageUrl: null,
  );

  final Map<String, String> _globalDirectory = {
    'LNK-1234-AB': 'Sarah Wilson',
    'LNK-5678-CD': 'Mike Ross',
    'LNK-9012-EF': 'Emma Watson',
    'LNK-4321-ZX': 'David Miller',
  };

  final List<ChatUser> _users = [
    ChatUser(name: 'Alex Rivera', lastMessage: 'See you there!', time: '2m ago', id: 'LNK-0001-AR'),
    ChatUser(name: 'Sarah Chen', lastMessage: 'The design looks great.', time: '15m ago', id: 'LNK-0002-SC'),
  ];

  void _addNewConnection(String linkerId) {
    if (_globalDirectory.containsKey(linkerId)) {
      final userName = _globalDirectory[linkerId]!;
      if (_users.any((u) => u.id == linkerId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Already connected with $userName')),
        );
        return;
      }
      setState(() {
        _users.insert(0, ChatUser(
          name: userName,
          lastMessage: 'Connected via Worldwide Link!',
          time: 'Just now',
          id: linkerId,
        ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully connected to $userName!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Linker ID. No user found.')),
      );
    }
  }

  void _updateName(String newName) {
    setState(() {
      _currentUser.name = newName;
    });
  }

  void _updateImage(String path) {
    setState(() {
      _currentUser.profileImageUrl = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      ChatListScreen(
        users: _users, 
        onAddConnection: _addNewConnection,
        myId: _currentUser.id,
      ),
      ProfileScreen(
        user: _currentUser, 
        onUpdateName: _updateName,
        onUpdateImage: _updateImage,
      ),
    ];

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.03), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class ChatListScreen extends StatelessWidget {
  final List<ChatUser> users;
  final Function(String) onAddConnection;
  final String myId;

  const ChatListScreen({super.key, required this.users, required this.onAddConnection, required this.myId});

  void _openScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(onScan: (id) {
          onAddConnection(id);
        }),
      ),
    );
  }

  void _showMyQrDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.qr_code_2_rounded, size: 200, color: theme.scaffoldBackgroundColor),
            ),
            const SizedBox(height: 24),
            const Text('My Linker ID', style: TextStyle(fontSize: 14, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(myId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showConnectionOptions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('Scan QR Code'),
              subtitle: const Text('Connect by scanning a Linker QR', style: TextStyle(fontSize: 12, color: Colors.white24)),
              onTap: () {
                Navigator.pop(context);
                _openScanner(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded),
              title: const Text('My QR Code'),
              subtitle: const Text('Share your unique Linker ID', style: TextStyle(fontSize: 12, color: Colors.white24)),
              onTap: () {
                Navigator.pop(context);
                _showMyQrDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurface.withOpacity(0.4);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          title: const Text('Messages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              onPressed: () => _showConnectionOptions(context),
              icon: const Icon(Icons.add_rounded, size: 28),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final user = users[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MessagePage(userName: user.name),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.surface,
                        child: Icon(Icons.person, color: theme.colorScheme.onSurface.withOpacity(0.2), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                Text(
                                  user.time,
                                  style: TextStyle(color: secondaryText, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: secondaryText, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: users.length,
          ),
        ),
      ],
    );
  }
}

class QRScannerScreen extends StatelessWidget {
  final Function(String) onScan;
  const QRScannerScreen({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              onScan(barcode.rawValue!);
              Navigator.of(context).pop();
              break;
            }
          }
        },
      ),
    );
  }
}

class MessagePage extends StatefulWidget {
  final String userName;
  const MessagePage({super.key, required this.userName});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(text: 'Hey! Are we still on for the meeting today?', isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
    ChatMessage(text: 'Yeah, that sounds perfect. Let\'s do it.', isMe: true, timestamp: DateTime.now().subtract(const Duration(minutes: 2))),
  ];

  void _handleSend() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.insert(0, ChatMessage(
        text: _controller.text.trim(),
        isMe: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurface.withOpacity(0.4);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 56,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.surface,
              child: Icon(Icons.person, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.2)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Online', style: TextStyle(fontSize: 12, color: Colors.green.withOpacity(0.6))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              reverse: true,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: message.isMe ? theme.colorScheme.onSurface.withOpacity(0.07) : theme.colorScheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(message.isMe ? 20 : 4),
                        bottomRight: Radius.circular(message.isMe ? 4 : 20),
                      ),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: theme.colorScheme.onSurface.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')} ${message.timestamp.hour >= 12 ? 'PM' : 'AM'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: secondaryText.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _handleSend(),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: secondaryText, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.onSurface.withOpacity(0.07),
                    child: IconButton(
                      onPressed: _handleSend,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
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

  const ProfileScreen({
    super.key, 
    required this.user, 
    required this.onUpdateName,
    required this.onUpdateImage,
  });

  Future<void> _pickImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        onUpdateImage(image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: user.name);
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Edit Name', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              onUpdateName(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurface.withOpacity(0.4);

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: theme.colorScheme.surface,
                  child: user.profileImageUrl == null 
                    ? Icon(Icons.person, size: 60, color: theme.colorScheme.onSurface.withOpacity(0.2))
                    : ClipOval(
                        child: Image.file(
                          File(user.profileImageUrl!), 
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _pickImage(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _showEditNameDialog(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined, size: 16, color: Colors.white24),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, size: 14, color: secondaryText),
                const SizedBox(width: 6),
                Text(
                  user.id,
                  style: TextStyle(color: secondaryText, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildProfileOption(theme, Icons.notifications_none, 'Notifications'),
          _buildProfileOption(theme, Icons.privacy_tip_outlined, 'Privacy'),
          _buildProfileOption(theme, Icons.help_outline, 'Help & Support'),
          _buildProfileOption(theme, Icons.logout, 'Log out', color: Colors.redAccent.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _buildProfileOption(ThemeData theme, IconData icon, String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color ?? theme.colorScheme.onSurface.withOpacity(0.7)),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white24),
        onTap: () {},
      ),
    );
  }
}
