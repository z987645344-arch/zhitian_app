class ChatSessionSummary {
  const ChatSessionSummary({
    required this.sessionId,
    required this.title,
    required this.lastActive,
    required this.messageCount,
    this.displayName,
  });

  final String sessionId;
  final String title;
  final String lastActive;
  final int messageCount;
  final String? displayName;

  String get visibleTitle {
    final custom = displayName?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final fallback = title.trim();
    return fallback.isEmpty ? '未命名对话' : fallback;
  }

  ChatSessionSummary copyWith({
    String? displayName,
    bool clearDisplayName = false,
  }) {
    return ChatSessionSummary(
      sessionId: sessionId,
      title: title,
      lastActive: lastActive,
      messageCount: messageCount,
      displayName: clearDisplayName ? null : displayName ?? this.displayName,
    );
  }

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) {
    return ChatSessionSummary(
      sessionId: (json['session_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      lastActive: (json['last_active'] ?? '').toString(),
      messageCount: _asInt(json['message_count']),
      displayName: json['display_name']?.toString(),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
