import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/thinking_bubble.dart';
import 'history_page.dart';
import 'settings_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(ChatProvider provider) async {
    final text = _controller.text;
    if (text.trim().isEmpty || provider.isSending) return;
    _controller.clear();
    await provider.sendMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        _scrollToBottom();
        final visibleMessages = provider.messages
            .where(_shouldShowMessage)
            .toList();
        final showThinking = provider.isThinking;
        final itemCount = visibleMessages.length + (showThinking ? 1 : 0);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '新建对话',
              icon: const Icon(Icons.add_comment),
              onPressed: provider.newChat,
            ),
            title: const Text('知天'),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: '历史记录',
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryPage(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: itemCount == 0
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (showThinking && index == visibleMessages.length) {
                            return const ThinkingBubble();
                          }
                          return MessageBubble(message: visibleMessages[index]);
                        },
                      ),
              ),
              ChatComposer(
                controller: _controller,
                isSending: provider.isSending,
                onSend: () => _send(provider),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _shouldShowMessage(Message message) {
    if (message.role == MessageRole.assistant && message.content.isEmpty) {
      return false;
    }
    return true;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '开始对话',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
