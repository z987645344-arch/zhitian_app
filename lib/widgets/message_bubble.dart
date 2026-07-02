import 'package:flutter/material.dart';

import '../models/message.dart';
import 'streaming_cursor.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colors = Theme.of(context).colorScheme;
    final bubbleColor = isUser
        ? colors.primary
        : colors.surfaceContainerHighest;
    final textColor = isUser ? colors.onPrimary : colors.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: Radius.circular(isUser ? 8 : 2),
              bottomRight: Radius.circular(isUser ? 2 : 8),
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
    ).textTheme.bodyLarge?.copyWith(color: color, height: 1.35);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(content, style: style),
        if (showCursor) StreamingCursor(color: color),
      ],
    );
  }
}
