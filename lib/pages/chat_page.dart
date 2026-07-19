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
              final showInspector = constraints.maxWidth >= 1180;
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
                                  showModeSelector: !showInspector,
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
                                            'AI 生成内容仅供参考，请结合实际情况判断',
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
                  if (showInspector && _section == _WorkspaceSection.chat)
                    _RightPanel(
                      provider: provider,
                      openHistory: () =>
                          _showSection(_WorkspaceSection.history),
                      openFiles: () => _showSection(_WorkspaceSection.files),
                      openToolbox: () =>
                          _showSection(_WorkspaceSection.toolbox),
                      openSettings: () =>
                          _showSection(_WorkspaceSection.settings),
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
      width: compact ? 72 : 260,
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 16,
            18,
            compact ? 8 : 16,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Brand(compact: compact, onNewChat: onNewChat),
              const SizedBox(height: 22),
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
                label: '对话',
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
                borderRadius: BorderRadius.circular(10),
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
                    '智能工作台',
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
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: compact ? 42 : 44,
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
                      color: selected ? AppColors.text : AppColors.textMuted,
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
            padding: const EdgeInsets.all(8),
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
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.background,
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
                  ? AppColors.primaryContainer
                  : AppColors.surfaceLow,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(20),
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

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.provider,
    required this.openHistory,
    required this.openFiles,
    required this.openToolbox,
    required this.openSettings,
  });
  final ChatProvider provider;
  final VoidCallback openHistory;
  final VoidCallback openFiles;
  final VoidCallback openToolbox;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          children: [
            const _PanelHeading(title: '工作模式', icon: Icons.tune),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fast', label: Text('快速')),
                  ButtonSegment(value: 'expert', label: Text('专家')),
                ],
                selected: {provider.mode},
                onSelectionChanged: provider.isSending
                    ? null
                    : (selection) => provider.setMode(selection.first),
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 12),
            _ModeSummary(mode: provider.mode),
            const SizedBox(height: 26),
            const _PanelHeading(title: '可用能力', icon: Icons.widgets_outlined),
            const SizedBox(height: 10),
            const _UtilityCard(
              icon: Icons.attach_file,
              title: '附件阅读',
              subtitle: '在输入框上传文档并结合内容提问',
            ),
            _UtilityCard(
              icon: Icons.build_outlined,
              title: '格式与 PDF 工具',
              subtitle: '转换、合并和拆分本地文档',
              onTap: openToolbox,
            ),
            _UtilityCard(
              icon: Icons.folder_outlined,
              title: '我的文件',
              subtitle: '查看、预览、下载和管理产物',
              onTap: openFiles,
            ),
            _UtilityCard(
              icon: Icons.history,
              title: '历史记录',
              subtitle: '${provider.sessions.length} 个可用会话',
              onTap: openHistory,
            ),
            const SizedBox(height: 20),
            const _PanelHeading(title: '知识与上下文', icon: Icons.storage_outlined),
            const SizedBox(height: 10),
            const _InfoRow(label: '企业知识库', value: '已连接'),
            const _InfoRow(label: '长期记忆', value: '自动检索'),
            const _InfoRow(label: '附件上下文', value: '按本轮注入'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: openSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('工作台设置'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ModeSummary extends StatelessWidget {
  const _ModeSummary({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final expert = mode == 'expert';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        expert ? '完整意图分类、联网搜索、复杂任务、文件生成与转换。' : '上下文问答、知识库检索与附件阅读，单次最多 2 次模型调用。',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          height: 1.55,
        ),
      ),
    );
  }
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '开始对话',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            '对话、检索、阅读附件或生成可交付文件',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
