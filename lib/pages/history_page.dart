import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_session.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, MemoryService? apiService})
    : _apiService = apiService;

  final MemoryService? _apiService;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final MemoryService _apiService;

  bool _isLoading = true;
  bool _isClearing = false;
  final Set<String> _busySessions = {};
  List<ChatSessionSummary> _sessions = [];

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final sessions = await _apiService.getSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    if (_isClearing) return;
    final provider = context.read<ChatProvider>();
    final sessionId = provider.sessionId;
    setState(() => _isClearing = true);
    final success = await _apiService.clearHistory(sessionId);
    if (!mounted) return;

    if (success) {
      provider.newChat();
      setState(() {
        _sessions.removeWhere((item) => item.sessionId == sessionId);
        _isClearing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('历史记录已清空')));
      return;
    }

    setState(() => _isClearing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('清空失败，请稍后重试')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('历史记录'),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          IconButton(
            tooltip: '清空历史',
            onPressed: _isClearing || _sessions.isEmpty ? null : _clearHistory,
            icon: _isClearing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(onRefresh: _loadHistory, child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: Text('暂无历史记录')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _SessionTile(
          session: session,
          selected: session.sessionId == context.read<ChatProvider>().sessionId,
          onTap: () => _openSession(session.sessionId),
          busy: _busySessions.contains(session.sessionId),
          onRename: () => _renameSession(session),
          onDelete: () => _deleteSession(session),
        );
      },
    );
  }

  Future<void> _openSession(String sessionId) async {
    final history = await _apiService.getHistory(sessionId);
    if (!mounted) return;
    await context.read<ChatProvider>().restoreSession(sessionId, history);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _renameSession(ChatSessionSummary session) async {
    var editedName = session.displayName ?? '';
    final result = await showDialog<_RenameResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextFormField(
          initialValue: editedName,
          autofocus: true,
          maxLength: 50,
          onChanged: (value) => editedName = value,
          decoration: const InputDecoration(hintText: '输入1-50个字符'),
        ),
        actions: [
          if (session.displayName?.isNotEmpty == true)
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(const _RenameResult(reset: true)),
              child: const Text('恢复默认'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = editedName.trim();
              if (value.isEmpty || value.length > 50) return;
              Navigator.of(dialogContext).pop(_RenameResult(value: value));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busySessions.add(session.sessionId));
    try {
      final displayName = await _apiService.renameSession(
        session.sessionId,
        result.reset ? null : result.value,
      );
      if (!mounted) return;
      setState(() {
        final index = _sessions.indexWhere(
          (item) => item.sessionId == session.sessionId,
        );
        if (index >= 0) {
          _sessions[index] = _sessions[index].copyWith(
            displayName: displayName,
            clearDisplayName: displayName == null,
          );
        }
      });
      context.read<ChatProvider>().updateSessionDisplayName(
        session.sessionId,
        displayName,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重命名失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _busySessions.remove(session.sessionId));
    }
  }

  Future<void> _deleteSession(ChatSessionSummary session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除“${session.visibleTitle}”及其全部记忆吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busySessions.add(session.sessionId));
    final success = await _apiService.deleteSession(session.sessionId);
    if (!mounted) return;
    if (success) {
      context.read<ChatProvider>().removeSession(session.sessionId);
      setState(() {
        _sessions.removeWhere((item) => item.sessionId == session.sessionId);
        _busySessions.remove(session.sessionId);
      });
      return;
    }
    setState(() => _busySessions.remove(session.sessionId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
  }
}

class _RenameResult {
  const _RenameResult({this.value, this.reset = false});

  final String? value;
  final bool reset;
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.busy,
    required this.onRename,
    required this.onDelete,
  });

  final ChatSessionSummary session;
  final bool selected;
  final VoidCallback onTap;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryContainer : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.surfaceLow,
                foregroundColor: AppColors.primary,
                child: const Icon(Icons.chat_bubble_outline, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.visibleTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '重命名',
                          visualDensity: VisualDensity.compact,
                          onPressed: busy ? null : onRename,
                          icon: const Icon(Icons.edit_outlined, size: 19),
                        ),
                        IconButton(
                          tooltip: '删除会话',
                          visualDensity: VisualDensity.compact,
                          onPressed: busy ? null : onDelete,
                          icon: busy
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline, size: 19),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${session.messageCount} 条消息 · ${session.lastActive}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
