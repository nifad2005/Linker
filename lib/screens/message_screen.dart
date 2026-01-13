import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import 'message_input.dart';

class MessagePage extends StatefulWidget {
  final ChatUser user;
  final Function(String) onMessageSent;
  final Function(bool) onSendTyping;
  final VoidCallback onSendSeen;
  final Function(String, {bool forEveryone}) onDeleteMessage;
  final Function(String, String) onReactToMessage;
  final String myId;

  const MessagePage({
    super.key, 
    required this.user, 
    required this.onMessageSent,
    required this.onSendTyping,
    required this.onSendSeen,
    required this.onDeleteMessage,
    required this.onReactToMessage,
    required this.myId,
  });

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  StreamSubscription? _subscription;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    widget.onSendSeen();
    _subscription = messageUpdates.stream.listen((peerId) {
      if (peerId == widget.user.id && mounted) {
        widget.onSendSeen();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.onSendTyping(false);
    _typingTimer?.cancel();
    _subscription?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    widget.onMessageSent(text);
    widget.onSendTyping(false);
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _onTypingChanged(bool isTyping) {
    if (isTyping) {
      widget.onSendTyping(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () => widget.onSendTyping(false));
    } else {
      widget.onSendTyping(false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showActionMenu(ChatMessage message) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '😮', '😢', '🔥', '👍'].map((emoji) {
                  final bool isSelected = message.reactions[emoji]?.contains(widget.myId) ?? false;
                  return GestureDetector(
                    onTap: () {
                      widget.onReactToMessage(message.id, emoji);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.greenAccent.withAlpha(50) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: Colors.white10, height: 24),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white70),
              title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete for me', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                widget.onDeleteMessage(message.id, forEveryone: false);
                Navigator.pop(context);
              },
            ),
            if (message.isMe && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: const Text('Delete for everyone', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  widget.onDeleteMessage(message.id, forEveryone: true);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by parent Container
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withAlpha(13),
              child: Text(widget.user.name.isNotEmpty ? widget.user.name.substring(0, 1).toUpperCase() : '?'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(widget.user.isTyping ? 'typing...' : (widget.user.isOnline ? 'Online' : 'Offline'),
                      style: TextStyle(fontSize: 11, color: widget.user.isTyping || widget.user.isOnline ? Colors.greenAccent : Colors.white38)),
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
                if (m.isSystem) return _buildSystemMessage(m);
                return AnimatedMessageBubble(
                  key: ValueKey(m.id),
                  message: m,
                  onLongPress: () => _showActionMenu(m),
                );
              },
            ),
          ),
          MessageInput(
            onSendMessage: _sendMessage,
            onTypingChanged: _onTypingChanged,
            focusNode: _focusNode,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessage m) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withAlpha(13), borderRadius: BorderRadius.circular(12)),
        child: Text(m.text, style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
      ),
    );
  }
}

class AnimatedMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onLongPress;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.onLongPress,
  });

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.fastLinearToSlowEaseIn,
    ));

    final age = DateTime.now().difference(widget.message.timestamp);
    if (age.inSeconds < 2) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final screenWidth = MediaQuery.of(context).size.width;
    final sideMargin = (screenWidth * 0.15).clamp(16.0, 300.0);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: m.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
          child: Align(
            alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: GestureDetector(
              onLongPress: widget.onLongPress,
              child: Container(
                margin: EdgeInsets.only(
                  bottom: 6,
                  left: m.isMe ? sideMargin : 16,
                  right: m.isMe ? 16 : sideMargin,
                ),
                child: Column(
                  crossAxisAlignment: m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(maxWidth: screenWidth * 0.72),
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
                      decoration: BoxDecoration(
                        color: m.isDeleted 
                            ? Colors.white.withAlpha(13) 
                            : (m.isMe ? Colors.greenAccent.withAlpha(40) : const Color(0xFF242424)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(m.isMe ? 16 : 4),
                          bottomRight: Radius.circular(m.isMe ? 4 : 16),
                        ),
                        border: m.isDeleted ? Border.all(color: Colors.white10) : null,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(
                            m.text,
                            style: TextStyle(
                              fontSize: 15,
                              color: m.isDeleted ? Colors.white38 : Colors.white.withAlpha(240),
                              fontStyle: m.isDeleted ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat.jm().format(m.timestamp),
                                  style: const TextStyle(fontSize: 8.5, color: Colors.white24),
                                ),
                                if (m.isMe) ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.done_all,
                                    size: 11,
                                    color: m.isSeen ? Colors.greenAccent : Colors.white12,
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (m.reactions.isNotEmpty)
                      Transform.translate(
                        offset: const Offset(0, -4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: m.reactions.entries.map((entry) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2C),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Text(entry.key, style: const TextStyle(fontSize: 12)),
                                  if (entry.value.length > 1)
                                    Text(' ${entry.value.length}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
