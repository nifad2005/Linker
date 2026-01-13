import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import 'message_screen.dart';
import 'qr_scanner_screen.dart';
import 'my_id_screen.dart';

class ChatListScreen extends StatefulWidget {
  final List<ChatUser> users;
  final Function(String) onAddConnection;
  final Function(String) onDeleteConnection;
  final Function(String, String) onSendMessage;
  final Function(String, bool) onSendTyping;
  final Function(String) onSendSeen;
  final Function(String) onClearUnread;
  final Function(String, String, {bool forEveryone}) onDeleteMessage;
  final Function(String, String, String) onReactToMessage;
  final String myId;
  final bool isConnected;
  final ChatUser? selectedUser;
  final Function(ChatUser)? onUserSelected;

  const ChatListScreen({
    super.key, 
    required this.users, 
    required this.onAddConnection, 
    required this.onDeleteConnection,
    required this.onSendMessage,
    required this.onSendTyping,
    required this.onSendSeen,
    required this.onClearUnread,
    required this.onDeleteMessage,
    required this.onReactToMessage,
    required this.myId, 
    required this.isConnected,
    this.selectedUser,
    this.onUserSelected,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    )..repeat();

    _shimmerAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -1.0, end: 2.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(2.0),
        weight: 75,
      ),
    ]).animate(_shimmerController);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

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
                color: widget.isConnected ? Colors.green : Colors.red,
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
      body: widget.users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public, size: 80, color: Colors.white.withAlpha(13)),
                  const SizedBox(height: 24),
                  const Text('No global links yet', style: TextStyle(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddMenu(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(13),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Connect with ID'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.users.length,
              itemBuilder: (context, index) {
                final user = widget.users[index];
                final lastMsg = user.messages.isNotEmpty ? user.messages.first : null;
                final bool hasUnread = user.unreadCount > 0;
                final bool isSelected = widget.selectedUser?.id == user.id;
                
                return Dismissible(
                  key: Key(user.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red.withAlpha(25),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                  confirmDismiss: (dir) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: const Text('Delete Connection'),
                        content: Text('Are you sure you want to remove ${user.name}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true), 
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent))
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => widget.onDeleteConnection(user.id),
                  child: AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, child) {
                      return ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (bounds) {
                          if (!hasUnread) return const LinearGradient(colors: [Colors.transparent, Colors.transparent]).createShader(bounds);
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [
                              _shimmerAnimation.value - 0.2,
                              _shimmerAnimation.value,
                              _shimmerAnimation.value + 0.2,
                            ],
                            colors: [
                              Colors.white.withAlpha(0),
                              Colors.white.withAlpha(13),
                              Colors.white.withAlpha(0),
                            ],
                          ).createShader(bounds);
                        },
                        child: child,
                      );
                    },
                    child: Container(
                      color: isSelected ? Colors.greenAccent.withAlpha(20) : (hasUnread ? Colors.greenAccent.withAlpha(5) : Colors.transparent),
                      child: ListTile(
                        selected: isSelected,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white.withAlpha(13),
                              child: Text(user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?', 
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                            ),
                            if (user.isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF121212), width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name, 
                                style: TextStyle(
                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600, 
                                  fontSize: 17,
                                  color: hasUnread ? Colors.white : Colors.white.withAlpha(230)
                                )
                              ),
                            ),
                            if (hasUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${user.unreadCount}', 
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)
                                ),
                              ),
                          ],
                        ),
                        subtitle: _buildSubtitle(user, lastMsg, hasUnread),
                        trailing: lastMsg != null 
                          ? Text(
                              DateFormat('HH:mm').format(lastMsg.timestamp), 
                              style: TextStyle(
                                fontSize: 12, 
                                color: hasUnread ? Colors.greenAccent : Colors.white24,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal
                              )
                            )
                          : null,
                        onTap: () {
                          widget.onClearUnread(user.id);
                          if (widget.onUserSelected != null) {
                            widget.onUserSelected!(user);
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => MessagePage(
                              user: user,
                              onMessageSent: (text) => widget.onSendMessage(user.id, text),
                              onSendTyping: (isTyping) => widget.onSendTyping(user.id, isTyping),
                              onSendSeen: () => widget.onSendSeen(user.id),
                              onDeleteMessage: (msgId, {bool forEveryone = false}) => widget.onDeleteMessage(user.id, msgId, forEveryone: forEveryone),
                              onReactToMessage: (msgId, emoji) => widget.onReactToMessage(user.id, msgId, emoji),
                              myId: widget.myId,
                            )));
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSubtitle(ChatUser user, ChatMessage? lastMsg, bool hasUnread) {
    if (user.isTyping) {
      return const Text('typing...', style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic));
    }
    
    if (lastMsg == null) {
      return const Text('New connection', style: TextStyle(color: Colors.white38));
    }

    String text = lastMsg.isDeleted ? 'Message deleted' : lastMsg.text;
    bool isReacted = lastMsg.reactions.isNotEmpty;

    return Row(
      children: [
        if (isReacted && !lastMsg.isDeleted)
           Padding(
             padding: const EdgeInsets.only(right: 4),
             child: Text(lastMsg.reactions.keys.first, style: const TextStyle(fontSize: 12)),
           ),
        Expanded(
          child: Text(
            text, 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis, 
            style: TextStyle(
              color: hasUnread ? Colors.white.withAlpha(180) : (lastMsg.isSystem || lastMsg.isDeleted ? Colors.greenAccent : Colors.white38),
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              fontStyle: lastMsg.isDeleted ? FontStyle.italic : FontStyle.normal,
            )
          ),
        ),
      ],
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
              leading: const Icon(Icons.qr_code_scanner, color: Colors.greenAccent),
              title: const Text('Scan QR Code'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, MaterialPageRoute(builder: (context) => QRScannerScreen(onScan: widget.onAddConnection)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.greenAccent),
              title: const Text('My Global ID'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, MaterialPageRoute(builder: (context) => MyIdPage(myId: widget.myId)));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
