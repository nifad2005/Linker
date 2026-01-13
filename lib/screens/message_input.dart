import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

class MessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(bool) onTypingChanged;
  final FocusNode focusNode;

  const MessageInput({
    super.key,
    required this.onSendMessage,
    required this.onTypingChanged,
    required this.focusNode,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isTextEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final bool isEmpty = _controller.text.trim().isEmpty;
    if (isEmpty != _isTextEmpty) {
      setState(() => _isTextEmpty = isEmpty);
    }
    widget.onTypingChanged(!isEmpty);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(13), width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Shortcuts(
              shortcuts: {
                const SingleActivator(LogicalKeyboardKey.enter): const SendMessageIntent(),
              },
              child: Actions(
                actions: {
                  SendMessageIntent: CallbackAction<SendMessageIntent>(
                    onInvoke: (_) => _handleSend(),
                  ),
                },
                child: TextField(
                  controller: _controller,
                  focusNode: widget.focusNode,
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withAlpha(13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isTextEmpty ? null : _handleSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isTextEmpty ? Colors.white.withAlpha(13) : Colors.greenAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded, 
                color: _isTextEmpty ? Colors.white24 : Colors.black87, 
                size: 20
              ),
            ),
          ),
        ],
      ),
    );
  }
}
