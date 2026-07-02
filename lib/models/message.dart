enum MessageRole { user, assistant }

class Message {
  Message({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  final MessageRole role;
  String content;
  bool isStreaming;

  bool get isUser => role == MessageRole.user;
}
