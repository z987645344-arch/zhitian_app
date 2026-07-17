import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_session.dart';
import '../models/message.dart';
import '../models/pending_attachment.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({ChatStreamingService? apiService, String? initialSessionId})
    : _apiService = apiService ?? ApiService(),
      _sessionId = initialSessionId?.trim().isNotEmpty == true
          ? initialSessionId!.trim()
          : const Uuid().v4() {
    unawaited(_persistSessionId());
  }

  final ChatStreamingService _apiService;
  String _sessionId;
  final List<Message> _messages = [];
  final List<ChatSessionSummary> _sessions = [];
  final List<PendingAttachment> _pendingAttachments = [];

  bool _isSending = false;
  bool _isThinking = false;
  String _mode = 'fast';

  List<Message> get messages => List.unmodifiable(_messages);
  List<ChatSessionSummary> get sessions => List.unmodifiable(_sessions);
  String get sessionId => _sessionId;
  bool get isSending => _isSending;
  bool get isThinking => _isThinking;
  String get mode => _mode;
  List<PendingAttachment> get pendingAttachments =>
      List.unmodifiable(_pendingAttachments);
  bool get hasUploadingAttachments => _pendingAttachments.any(
    (item) => item.status == AttachmentUploadStatus.uploading,
  );
  bool get hasSuccessfulAttachments => _pendingAttachments.any(
    (item) => item.status == AttachmentUploadStatus.success,
  );

  bool canSend(String text) {
    return !_isSending &&
        !hasUploadingAttachments &&
        (text.trim().isNotEmpty || hasSuccessfulAttachments);
  }

  void setMode(String mode) {
    if (_isSending || mode == _mode || (mode != 'fast' && mode != 'expert')) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }

  void newChat() {
    _messages.clear();
    _sessionId = const Uuid().v4();
    _isThinking = false;
    _isSending = false;
    _pendingAttachments.clear();
    _sessions.removeWhere((item) => item.sessionId == _sessionId);
    _sessions.insert(
      0,
      ChatSessionSummary(
        sessionId: _sessionId,
        title: '新对话',
        lastActive: DateTime.now().toIso8601String(),
        messageCount: 0,
      ),
    );
    unawaited(_persistSessionId());
    notifyListeners();
  }

  Future<void> refreshSessions() async {
    if (_apiService is! MemoryService) return;
    final remote = await (_apiService as MemoryService).getSessions();
    final currentLocal = _sessions
        .where((item) => item.sessionId == _sessionId && item.messageCount == 0)
        .toList();
    _sessions
      ..clear()
      ..addAll(currentLocal)
      ..addAll(
        remote.where(
          (item) => !_sessions.any(
            (existing) => existing.sessionId == item.sessionId,
          ),
        ),
      );
    notifyListeners();
  }

  Future<void> openSession(String sessionId) async {
    if (_apiService is! MemoryService || sessionId.isEmpty) return;
    final history = await (_apiService as MemoryService).getHistory(sessionId);
    _sessionId = sessionId;
    _messages
      ..clear()
      ..addAll(
        history.map(
          (item) => Message.fromHistory(Map<String, dynamic>.from(item)),
        ),
      );
    _pendingAttachments.clear();
    _isSending = false;
    _isThinking = false;
    await _persistSessionId();
    notifyListeners();
  }

  Future<void> restoreSession(String sessionId, List<Map> history) async {
    if (sessionId.isEmpty) return;
    _sessionId = sessionId;
    _messages
      ..clear()
      ..addAll(
        history.map(
          (item) => Message.fromHistory(Map<String, dynamic>.from(item)),
        ),
      );
    _pendingAttachments.clear();
    _isSending = false;
    _isThinking = false;
    await _persistSessionId();
    notifyListeners();
  }

  void updateSessionDisplayName(String sessionId, String? displayName) {
    final index = _sessions.indexWhere((item) => item.sessionId == sessionId);
    if (index < 0) return;
    _sessions[index] = _sessions[index].copyWith(
      displayName: displayName,
      clearDisplayName: displayName == null,
    );
    notifyListeners();
  }

  void removeSession(String sessionId) {
    if (sessionId == _sessionId) {
      newChat();
      return;
    }
    _sessions.removeWhere((item) => item.sessionId == sessionId);
    notifyListeners();
  }

  Future<void> _persistSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiService.chatSessionIdKey, _sessionId);
  }

  Future<void> addAttachment(File file) async {
    final localId = const Uuid().v4();
    final filename = file.uri.pathSegments.last;
    _pendingAttachments.add(
      PendingAttachment(
        attachmentId: localId,
        filename: filename,
        status: AttachmentUploadStatus.uploading,
      ),
    );
    notifyListeners();

    try {
      final extension = filename.split('.').last.toLowerCase();
      if (!const {
        'txt',
        'md',
        'pdf',
        'docx',
        'doc',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
      }.contains(extension)) {
        throw Exception('不支持该文件格式');
      }
      if (await file.length() > 20 * 1024 * 1024) {
        throw Exception('文件超过20MB限制');
      }
      final result = await _apiService.uploadChatAttachment(sessionId, file);
      _replaceAttachment(
        localId,
        PendingAttachment(
          attachmentId: result.attachmentId,
          filename: result.filename,
          status: AttachmentUploadStatus.success,
        ),
      );
    } catch (error) {
      _replaceAttachment(
        localId,
        PendingAttachment(
          attachmentId: localId,
          filename: filename,
          status: AttachmentUploadStatus.failed,
          errorMessage: _briefError(error),
        ),
      );
    }
  }

  void removeAttachment(String attachmentId) {
    _pendingAttachments.removeWhere(
      (item) => item.attachmentId == attachmentId,
    );
    notifyListeners();
  }

  void _replaceAttachment(String currentId, PendingAttachment replacement) {
    final index = _pendingAttachments.indexWhere(
      (item) => item.attachmentId == currentId,
    );
    if (index < 0) return;
    _pendingAttachments[index] = replacement;
    notifyListeners();
  }

  void addUserMessage(
    String content, {
    List<String> attachmentIds = const [],
    List<String> attachmentFilenames = const [],
  }) {
    _messages.add(
      Message(
        role: MessageRole.user,
        content: content,
        attachmentIds: attachmentIds,
        attachmentFilenames: attachmentFilenames,
      ),
    );
    notifyListeners();
  }

  void addAssistantPlaceholder() {
    _messages.add(
      Message(role: MessageRole.assistant, content: '', isStreaming: true),
    );
    notifyListeners();
  }

  void appendChunk(String chunk) {
    if (_messages.isEmpty) return;
    final last = _messages.last;
    if (last.role != MessageRole.assistant || !last.isStreaming) return;
    if (_isThinking) {
      _isThinking = false;
    }
    last.content += chunk;
    notifyListeners();
  }

  void setAssistantCitations(List<Citation> citations) {
    if (_messages.isEmpty) return;
    final last = _messages.last;
    if (last.role != MessageRole.assistant) return;
    last.citations = citations;
    notifyListeners();
  }

  void setAssistantReasoning(String reasoning) {
    if (_messages.isEmpty) return;
    final last = _messages.last;
    if (last.role != MessageRole.assistant || reasoning.trim().isEmpty) return;
    last.reasoning = reasoning.trim();
    notifyListeners();
  }

  void finishStreaming() {
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      if (last.role == MessageRole.assistant) {
        last.isStreaming = false;
      }
    }
    _isThinking = false;
    _isSending = false;
    notifyListeners();
  }

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    final attachmentIds = _pendingAttachments
        .where((item) => item.status == AttachmentUploadStatus.success)
        .map((item) => item.attachmentId)
        .toList(growable: false);
    if (text.isEmpty && attachmentIds.isEmpty || !canSend(text)) return;
    final attachmentFilenames = _pendingAttachments
        .where((item) => item.status == AttachmentUploadStatus.success)
        .map((item) => item.filename)
        .toList(growable: false);

    _isSending = true;
    _isThinking = true;
    addUserMessage(
      text,
      attachmentIds: attachmentIds,
      attachmentFilenames: attachmentFilenames,
    );
    addAssistantPlaceholder();

    try {
      await for (final event in _apiService.chatStream(
        sessionId: sessionId,
        message: text,
        mode: _mode,
        attachmentIds: attachmentIds,
      )) {
        if (event.isDone) {
          _pendingAttachments.clear();
          unawaited(refreshSessions());
          finishStreaming();
          return;
        }
        if (event.hasCitations) {
          setAssistantCitations(event.citations ?? const []);
          continue;
        }
        if (event.hasReasoning) {
          setAssistantReasoning(event.reasoning ?? '');
          continue;
        }
        final chunk = event.chunk;
        if (chunk != null) {
          appendChunk(chunk);
        }
      }
    } catch (e) {
      appendChunk('⚠️ 发生错误：${_briefError(e)}');
    }

    finishStreaming();
  }

  String _briefError(Object error) {
    final text = error.toString().replaceAll('\n', ' ');
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }
}
