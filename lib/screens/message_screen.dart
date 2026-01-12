import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';

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
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Listen for real-time updates for this specific user
    _subscription = messageUpdates.stream.listen((peerId) {
      if (peerId == widget.user.id) {
        if (mounted) {
          setState(() {});
          _scrollToBottom();
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ctrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
