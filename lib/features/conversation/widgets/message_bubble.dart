import 'package:flutter/material.dart';
class MessageBubble extends StatefulWidget {
  final String messageText;
  final bool isMe;
  final DateTime timestamp;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const MessageBubble({
    super.key,
    required this.messageText,
    required this.isMe,
    required this.timestamp,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = widget.isMe;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(!isMe && widget.isLastInGroup ? 4 : 20),
      bottomRight: Radius.circular(isMe && widget.isLastInGroup ? 4 : 20),
    );

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Elastic stretch physics for swipe-to-reply
        setState(() {
          _dragOffset += details.delta.dx;
          // Constrain drag and add friction
          if (isMe) {
            _dragOffset = _dragOffset.clamp(-80.0, 0.0);
          } else {
            _dragOffset = _dragOffset.clamp(0.0, 80.0);
          }
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset.abs() > 50) {
          // Trigger reply action
          // TODO: Trigger reply
        }
        // Spring back
        setState(() {
          _dragOffset = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(_dragOffset, 0, 0),
        margin: EdgeInsets.only(
          bottom: widget.isLastInGroup ? 8.0 : 2.0,
          left: isMe ? 40.0 : 8.0,
          right: isMe ? 8.0 : 40.0,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: borderRadius,
              boxShadow: widget.isLastInGroup ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ] : null,
            ),
            child: Text(
              widget.messageText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isMe 
                    ? theme.colorScheme.onPrimary 
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
