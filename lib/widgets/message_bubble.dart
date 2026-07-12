import 'package:flutter/material.dart';

import '../models/message.dart';
import 'streaming_cursor.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? const Color(0xFF1A73E8)
        : const Color(0xFFF5F5F5);
    final textColor = isUser ? Colors.white : const Color(0xFF1A1A1A);
    final showCitations =
        !isUser && !message.isStreaming && message.citations.isNotEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
              if (showCitations)
                _CitationPanel(
                  citations: message.citations,
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
            ],
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

class _CitationPanel extends StatelessWidget {
  const _CitationPanel({
    required this.citations,
    required this.expanded,
    required this.onToggle,
  });

  final List<Citation> citations;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final uniqueCitations = _dedupe(citations);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      size: 15,
                      color: Color(0xFF1A73E8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '引用来源 ${uniqueCitations.length}',
                      style: const TextStyle(
                        color: Color(0xFF1A73E8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: const Color(0xFF1A73E8),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                    const SizedBox(height: 6),
                    for (final citation in uniqueCitations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _citationLabel(citation),
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Citation> _dedupe(List<Citation> items) {
    final seen = <String>{};
    final result = <Citation>[];
    for (final item in items) {
      final key = '${item.source}#${item.docId}#${item.chunkIndex}';
      if (seen.add(key)) result.add(item);
    }
    return result;
  }

  String _citationLabel(Citation citation) {
    final chunk = citation.chunkIndex + 1;
    return '${citation.displaySource} · 片段 $chunk';
  }
}
