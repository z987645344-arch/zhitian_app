import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({ChatStreamingService? apiService})
    : _apiService = apiService ?? ApiService();

  final ChatStreamingService _apiService;
  String _sessionId = const Uuid().v4();
  final List<Message> _messages = [];

  bool _isSending = false;
  bool _isThinking = false;
  String _mode = 'fast';

  List<Message> get messages => List.unmodifiable(_messages);
  String get sessionId => _sessionId;
  bool get isSending => _isSending;
  bool get isThinking => _isThinking;
  String get mode => _mode;

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
    notifyListeners();
  }

  void addUserMessage(String content) {
    _messages.add(Message(role: MessageRole.user, content: content));
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
    if (text.isEmpty || _isSending) return;

    _isSending = true;
    _isThinking = true;
    addUserMessage(text);
    addAssistantPlaceholder();

    try {
      await for (final event in _apiService.chatStream(
        sessionId: sessionId,
        message: text,
        mode: _mode,
      )) {
        if (event.isDone) {
          finishStreaming();
          return;
        }
        if (event.hasCitations) {
          setAssistantCitations(event.citations ?? const []);
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
