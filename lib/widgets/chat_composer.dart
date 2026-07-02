import 'package:flutter/material.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: !isSending,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 15),
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: '输入消息',
                      hintStyle: TextStyle(color: Color(0xFF666666)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Opacity(
                opacity: isSending ? 0.4 : 1,
                child: SizedBox.square(
                  dimension: 44,
                  child: IconButton.filled(
                    tooltip: '发送',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isSending ? null : onSend,
                    icon: isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
