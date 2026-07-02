import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../services/api_service.dart';

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
  List<Map> _history = [];

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final sessionId = context.read<ChatProvider>().sessionId;
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final history = await _apiService.getHistory(sessionId);
    if (!mounted) return;
    setState(() {
      _history = history;
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
        _history = [];
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('历史记录'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        surfaceTintColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        shape: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
        actions: [
          IconButton(
            tooltip: '清空历史',
            onPressed: _isClearing || _history.isEmpty ? null : _clearHistory,
            icon: _isClearing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadHistory, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = _history[index];
        return _HistoryTile(
          role: (record['role'] ?? '').toString(),
          content: (record['content'] ?? '').toString(),
          timestamp: (record['timestamp'] ?? '').toString(),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String role;
  final String content;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: isUser
                  ? const Color(0xFFE8F0FE)
                  : const Color(0xFFF5F5F5),
              foregroundColor: isUser
                  ? const Color(0xFF1A73E8)
                  : const Color(0xFF666666),
              child: Icon(
                isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isUser ? '用户' : '知天',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          timestamp,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 15,
                      height: 1.35,
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
}
