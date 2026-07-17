import 'dart:convert';

enum MessageRole { user, assistant }

class Citation {
  const Citation({
    required this.source,
    required this.docId,
    required this.chunkIndex,
    required this.score,
  });

  final String source;
  final String docId;
  final int chunkIndex;
  final double score;

  String get displaySource {
    final normalized = source.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty || parts.last.isEmpty ? source : parts.last;
  }

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      source: (json['source'] ?? '').toString(),
      docId: (json['doc_id'] ?? json['docId'] ?? '').toString(),
      chunkIndex: _asInt(json['chunk_index'] ?? json['chunkIndex']),
      score: _asDouble(json['score']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'doc_id': docId,
      'chunk_index': chunkIndex,
      'score': score,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class Message {
  Message({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.reasoning,
    List<Citation>? citations,
    List<String>? attachmentIds,
    List<String>? attachmentFilenames,
  }) : citations = citations ?? [],
       attachmentIds = attachmentIds ?? [],
       attachmentFilenames = attachmentFilenames ?? [];

  final MessageRole role;
  String content;
  bool isStreaming;
  String? reasoning;
  List<Citation> citations;
  List<String> attachmentIds;
  List<String> attachmentFilenames;

  bool get isUser => role == MessageRole.user;

  List<String> get attachmentLabels {
    if (attachmentFilenames.isNotEmpty) return attachmentFilenames;
    return List<String>.generate(
      attachmentIds.length,
      (index) => '附件 ${index + 1}',
      growable: false,
    );
  }

  factory Message.fromHistory(Map<String, dynamic> json) {
    final role = json['role'] == 'user'
        ? MessageRole.user
        : MessageRole.assistant;
    return Message(
      role: role,
      content: (json['content'] ?? '').toString(),
      attachmentIds: _stringList(json['attachment_ids']),
      attachmentFilenames: _stringList(json['attachment_filenames']),
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return [];
    return raw
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class ChatStreamEvent {
  const ChatStreamEvent._({
    this.chunk,
    this.citations,
    this.reasoning,
    this.isDone = false,
  });

  final String? chunk;
  final List<Citation>? citations;
  final String? reasoning;
  final bool isDone;

  bool get hasChunk => chunk != null;
  bool get hasCitations => citations != null;
  bool get hasReasoning => reasoning != null;

  factory ChatStreamEvent.chunk(String value) {
    return ChatStreamEvent._(chunk: value);
  }

  factory ChatStreamEvent.citations(List<Citation> citations) {
    return ChatStreamEvent._(citations: citations);
  }

  factory ChatStreamEvent.reasoning(String reasoning) {
    return ChatStreamEvent._(reasoning: reasoning);
  }

  factory ChatStreamEvent.done() {
    return const ChatStreamEvent._(isDone: true);
  }
}

List<Citation> parseCitations(Object? raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((item) => Citation.fromJson(Map<String, dynamic>.from(item)))
      .where((citation) => citation.source.isNotEmpty)
      .toList();
}

List<Citation> parseCitationsJson(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is Map<String, dynamic>) {
    return parseCitations(decoded['citations']);
  }
  return [];
}
