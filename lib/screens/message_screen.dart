import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';

class MessagePage extends StatefulWidget {
  final ChatUser user;
  final Function(String) onMessageSent;
  final Function(bool) onSendTyping;
  final VoidCallback onSendSeen;

  const MessagePage({
    super.key, 
    required this.user, 
    required this.onMessageSent,
    required this.onSendTyping,
    required this.onSendSeen,
  });

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _subscription;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    
    // Mark messages as seen when entering the chat
    widget.onSendSeen();

    _subscription = messageUpdates.stream.listen((peerId) {
      if (peerId == widget.user.id) {
        if (mounted) {
          // If a new message arrived while we are here, mark it as seen
          widget.onSendSeen();
          setState(() {});
          _scrollToBottom();
        }
      }
    });

    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_ctrl.text.isNotEmpty) {
      widget.onSendTyping(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        widget.onSendTyping(false);
      });
    } else {
      widget.onSendTyping(false);
    }
  }

  @override
  void dispose() {
    widget.onSendTyping(false);
    _typingTimer?.cancel();
    _subscription?.cancel();
    _ctrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_ctrl.text.trim().isEmpty) return;
    widget.onMessageSent(_ctrl.text.trim());
    _ctrl.clear();
    widget.onSendTyping(false);
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
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  child: Text(widget.user.name.isNotEmpty ? widget.user.name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(fontSize: 14)),
                ),
                if (widget.user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF121212), width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.user.name, style: const TextStyle(fontSize: 16)),
                  if (widget.user.isTyping)
                    const Text('typing...', style: TextStyle(fontSize: 11, color: Colors.green, fontStyle: FontStyle.italic))
                  else
                    Text(
                      widget.user.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 11, 
                        color: widget.user.isOnline ? Colors.green : Colors.white38
                      ),
                    ),
                ],
              ),
            ),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(DateFormat('HH:mm').format(m.timestamp), style: const TextStyle(fontSize: 10, color: Colors.white12)),
                          if (m.isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all, 
                              size: 14, 
                              color: m.isSeen ? Colors.blueAccent : Colors.white12
                            ),
                          ]
                        ],
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
