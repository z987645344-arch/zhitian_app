import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_session.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/thinking_bubble.dart';
import 'files_page.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'toolbox_page.dart';

enum _WorkspaceSection { chat, history, files, toolbox, settings }

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  _WorkspaceSection _section = _WorkspaceSection.chat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().refreshSessions();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(ChatProvider provider) async {
    final text = _controller.text;
    if (!provider.canSend(text)) return;
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

  void _showSection(_WorkspaceSection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  void _startNewChat(ChatProvider provider) {
    provider.newChat();
    _showSection(_WorkspaceSection.chat);
  }

  Future<void> _openRecentSession(
    ChatProvider provider,
    String sessionId,
  ) async {
    await provider.openSession(sessionId);
    if (mounted) _showSection(_WorkspaceSection.chat);
  }

  Future<void> _renameRecentSession(
    ChatProvider provider,
    ChatSessionSummary session,
  ) async {
    var editedName = session.displayName ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextFormField(
          initialValue: editedName,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(hintText: '输入1-50个字符'),
          onChanged: (value) => editedName = value,
          onFieldSubmitted: (value) {
            final normalized = value.trim();
            if (normalized.isNotEmpty && normalized.length <= 50) {
              Navigator.of(dialogContext).pop(normalized);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final normalized = editedName.trim();
              if (normalized.isNotEmpty && normalized.length <= 50) {
                Navigator.of(dialogContext).pop(normalized);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    try {
      final saved = await provider.renameSession(session.sessionId, name);
      if (!saved && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重命名失败，请稍后重试')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重命名失败，请稍后重试')));
      }
    }
  }

  Future<void> _deleteRecentSession(
    ChatProvider provider,
    ChatSessionSummary session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除“${session.visibleTitle}”及其全部记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deleted = await provider.deleteSession(session.sessionId);
      if (!deleted && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        _scrollToBottom();
        final messages = provider.messages.where(_shouldShowMessage).toList();
        final itemCount = messages.length + (provider.isThinking ? 1 : 0);
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final compactRail = constraints.maxWidth < 760;
              return Row(
                children: [
                  _LeftPanel(
                    compact: compactRail,
                    provider: provider,
                    section: _section,
                    onNewChat: () => _startNewChat(provider),
                    openChat: () => _showSection(_WorkspaceSection.chat),
                    openHistory: () => _showSection(_WorkspaceSection.history),
                    openFiles: () => _showSection(_WorkspaceSection.files),
                    openToolbox: () => _showSection(_WorkspaceSection.toolbox),
                    openSettings: () =>
                        _showSection(_WorkspaceSection.settings),
                    openSession: (session) =>
                        _openRecentSession(provider, session.sessionId),
                    renameSession: (session) =>
                        _renameRecentSession(provider, session),
                    deleteSession: (session) =>
                        _deleteRecentSession(provider, session),
                  ),
                  Expanded(
                    child: _section == _WorkspaceSection.chat
                        ? ColoredBox(
                            color: AppColors.background,
                            child: Column(
                              children: [
                                _WorkspaceHeader(
                                  provider: provider,
                                  showModeSelector: true,
                                ),
                                Expanded(
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 900,
                                      ),
                                      child: itemCount == 0
                                          ? const _EmptyState()
                                          : ListView.builder(
                                              controller: _scrollController,
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    32,
                                                    26,
                                                    32,
                                                    18,
                                                  ),
                                              itemCount: itemCount,
                                              itemBuilder: (context, index) {
                                                if (provider.isThinking &&
                                                    index == messages.length) {
                                                  return const ThinkingBubble();
                                                }
                                                return MessageBubble(
                                                  message: messages[index],
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 900,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        0,
                                        24,
                                        18,
                                      ),
                                      child: Column(
                                        children: [
                                          ChatComposer(
                                            controller: _controller,
                                            isSending: provider.isSending,
                                            pendingAttachments:
                                                provider.pendingAttachments,
                                            hasUploadingAttachments: provider
                                                .hasUploadingAttachments,
                                            hasSuccessfulAttachments: provider
                                                .hasSuccessfulAttachments,
                                            onAddAttachment:
                                                provider.addAttachment,
                                            onRemoveAttachment:
                                                provider.removeAttachment,
                                            onSend: () => _send(provider),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            '请核对引用与关键事实后再使用回答内容',
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : switch (_section) {
                            _WorkspaceSection.history => HistoryPage(
                              onSessionOpened: () =>
                                  _showSection(_WorkspaceSection.chat),
                            ),
                            _WorkspaceSection.files => const FilesPage(),
                            _WorkspaceSection.toolbox => const ToolboxPage(),
                            _WorkspaceSection.settings => const SettingsPage(),
                            _WorkspaceSection.chat => const SizedBox.shrink(),
                          },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  bool _shouldShowMessage(Message message) =>
      message.content.isNotEmpty || message.attachmentIds.isNotEmpty;
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({
    required this.compact,
    required this.provider,
    required this.section,
    required this.onNewChat,
    required this.openChat,
    required this.openHistory,
    required this.openFiles,
    required this.openToolbox,
    required this.openSettings,
    required this.openSession,
    required this.renameSession,
    required this.deleteSession,
  });

  final bool compact;
  final ChatProvider provider;
  final _WorkspaceSection section;
  final VoidCallback onNewChat;
  final VoidCallback openChat;
  final VoidCallback openHistory;
  final VoidCallback openFiles;
  final VoidCallback openToolbox;
  final VoidCallback openSettings;
  final ValueChanged<ChatSessionSummary> openSession;
  final ValueChanged<ChatSessionSummary> renameSession;
  final ValueChanged<ChatSessionSummary> deleteSession;

  @override
  Widget build(BuildContext context) {
    final sessionCount = provider.sessions.length > 8
        ? 8
        : provider.sessions.length;
    return Container(
      width: compact ? 68 : 232,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 16,
            16,
            compact ? 8 : 16,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Brand(compact: compact, onNewChat: onNewChat),
              const SizedBox(height: 20),
              if (compact)
                IconButton.filled(
                  tooltip: '新建对话',
                  onPressed: onNewChat,
                  icon: const Icon(Icons.add_comment),
                )
              else
                FilledButton.icon(
                  onPressed: onNewChat,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('新建对话'),
                ),
              const SizedBox(height: 18),
              _NavItem(
                compact: compact,
                selected: section == _WorkspaceSection.chat,
                icon: Icons.chat_bubble_outline,
                label: '知识问答',
                onTap: openChat,
              ),
              _NavItem(
                compact: compact,
                icon: Icons.history,
                label: '历史记录',
                selected: section == _WorkspaceSection.history,
                onTap: openHistory,
              ),
              _NavItem(
                compact: compact,
                icon: Icons.folder_outlined,
                label: '我的文件',
                selected: section == _WorkspaceSection.files,
                onTap: openFiles,
              ),
              _NavItem(
                compact: compact,
                icon: Icons.build_outlined,
                label: '工具箱',
                selected: section == _WorkspaceSection.toolbox,
                onTap: openToolbox,
              ),
              _NavItem(
                compact: compact,
                icon: Icons.settings_outlined,
                label: '设置',
                selected: section == _WorkspaceSection.settings,
                onTap: openSettings,
              ),
              if (!compact) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(10, 28, 10, 10),
                  child: Text(
                    '最近会话',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: sessionCount == 0
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            '暂无会话',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: sessionCount,
                          itemBuilder: (context, index) {
                            final session = provider.sessions[index];
                            return _SessionLink(
                              session: session,
                              selected: session.sessionId == provider.sessionId,
                              onTap: () => openSession(session),
                              onRename: () => renameSession(session),
                              onDelete: () => deleteSession(session),
                            );
                          },
                        ),
                ),
              ] else
                const Spacer(),
              const Divider(height: 24),
              _AccountTile(compact: compact, onTap: openSettings),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact, required this.onNewChat});
  final bool compact;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: compact
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '知天',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '企业知识助手',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ],
        ),
        if (!compact)
          IconButton(
            tooltip: '新建对话',
            onPressed: onNewChat,
            icon: const Icon(Icons.add_comment, size: 20),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.compact,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final bool compact;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: selected ? 24 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  width: compact ? 39 : 41,
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                if (!compact)
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionLink extends StatefulWidget {
  const _SessionLink({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });
  final ChatSessionSummary session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_SessionLink> createState() => _SessionLinkState();
}

class _SessionLinkState extends State<_SessionLink> {
  bool _hoveringAction = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.selected ? AppColors.surfaceContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: widget.onRename,
                  child: Text(
                    widget.session.visibleTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                onEnter: (_) => setState(() => _hoveringAction = true),
                onExit: (_) => setState(() => _hoveringAction = false),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: _hoveringAction
                      ? IconButton(
                          tooltip: '删除会话',
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete_outline, size: 17),
                        )
                      : Center(
                          child: Text(
                            '${widget.session.messageCount}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
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

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.compact, required this.onTap});
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;
        final savedName =
            prefs?.getString(ApiService.usernameKey)?.trim() ?? '';
        final username = savedName.isEmpty ? '当前账号' : savedName;
        final role = prefs?.getString(ApiService.userRoleKey) ?? 'customer';
        final roleName = role == 'reviewer'
            ? '审核员账号'
            : role == 'employee'
            ? '员工账号'
            : '个人账号';
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(compact ? 7 : 8),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.primary,
                  child: Text(
                    username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          roleName,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.unfold_more,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.provider,
    required this.showModeSelector,
  });
  final ChatProvider provider;
  final bool showModeSelector;

  @override
  Widget build(BuildContext context) {
    var title = '新对话';
    for (final session in provider.sessions) {
      if (session.sessionId == provider.sessionId) {
        title = session.visibleTitle;
        break;
      }
    }
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.mode == 'expert' ? '专家代理正在工作' : '快速助手已就绪',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (showModeSelector) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fast', label: Text('快速')),
                ButtonSegment(value: 'expert', label: Text('专家')),
              ],
              selected: {provider.mode},
              onSelectionChanged: provider.isSending
                  ? null
                  : (selection) => provider.setMode(selection.first),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: provider.isSending
                  ? AppColors.surfaceContainer
                  : AppColors.surfaceLow,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: provider.isSending
                        ? AppColors.primary
                        : AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  provider.isSending ? '处理中' : '在线',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '今天需要了解什么？',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            '可以检索企业知识、阅读本轮附件，或处理本地文件',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
