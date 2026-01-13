import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models.dart';

// Intent for sending messages via keyboard shortcut
class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

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
  final FocusNode _focusNode = FocusNode();
  StreamSubscription? _subscription;
  Timer? _typingTimer;
  bool _isTextEmpty = true;

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
    final bool isEmpty = _ctrl.text.trim().isEmpty;
    if (isEmpty != _isTextEmpty) {
      setState(() => _isTextEmpty = isEmpty);
    }

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
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_ctrl.text.trim().isEmpty) return;
    
    final String text = _ctrl.text.trim();
    HapticFeedback.lightImpact();
    widget.onMessageSent(text);
    _ctrl.clear();
    
    // Keep focus after sending to allow rapid messaging
    _focusNode.requestFocus();
    
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
        elevation: 0,
        backgroundColor: const Color(0xFF121212),
        title: Row(
          children: [
            const SizedBox(width: 4),
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  child: Text(widget.user.name.isNotEmpty ? widget.user.name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(fontSize: 14, color: Colors.white)),
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
                  Text(widget.user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          color: m.isMe ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(m.isMe ? 18 : 4),
                            bottomRight: Radius.circular(m.isMe ? 4 : 18),
                          ),
                        ),
                        child: Text(m.text, style: const TextStyle(fontSize: 15, color: Colors.white)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(DateFormat('HH:mm').format(m.timestamp), style: const TextStyle(fontSize: 10, color: Colors.white24)),
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
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildInputSection(),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Shortcuts(
              shortcuts: <ShortcutActivator, Intent>{
                const SingleActivator(LogicalKeyboardKey.enter): const SendMessageIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  SendMessageIntent: CallbackAction<SendMessageIntent>(
                    onInvoke: (intent) => _sendMessage(),
                  ),
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10, width: 0.5),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 15),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isTextEmpty ? null : _sendMessage,
            child: AnimatedScale(
              scale: _isTextEmpty ? 0.9 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isTextEmpty ? Colors.white.withOpacity(0.05) : Colors.blueAccent,
                  shape: BoxShape.circle,
                  boxShadow: _isTextEmpty ? [] : [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _isTextEmpty ? Colors.white24 : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
