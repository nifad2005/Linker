import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import 'message_screen.dart';
import 'qr_scanner_screen.dart';
import 'my_id_screen.dart';

class ChatListScreen extends StatelessWidget {
  final List<ChatUser> users;
  final Function(String) onAddConnection;
  final Function(String, String) onSendMessage;
  final String myId;
  final bool isConnected;

  const ChatListScreen({
    super.key, 
    required this.users, 
    required this.onAddConnection, 
    required this.onSendMessage,
    required this.myId, 
    required this.isConnected
  });

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
                    onMessageSent: (text) => onSendMessage(user.id, text),
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
