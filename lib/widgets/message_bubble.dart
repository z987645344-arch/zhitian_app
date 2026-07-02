import 'package:flutter/material.dart';

import '../models/message.dart';
import 'streaming_cursor.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? const Color(0xFF1A73E8)
        : const Color(0xFFF5F5F5);
    final textColor = isUser ? Colors.white : const Color(0xFF1A1A1A);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
          ),
          child: _BubbleText(
            content: message.content,
            color: textColor,
            showCursor: message.isStreaming,
          ),
        ),
      ),
    );
  }
}

class _BubbleText extends StatelessWidget {
  const _BubbleText({
    required this.content,
    required this.color,
    required this.showCursor,
  });

  final String content;
  final Color color;
  final bool showCursor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: color, fontSize: 15, height: 1.35);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(content, style: style),
        if (showCursor) StreamingCursor(color: color),
      ],
    );
  }
}
