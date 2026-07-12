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
    List<Citation>? citations,
  }) : citations = citations ?? [];

  final MessageRole role;
  String content;
  bool isStreaming;
  List<Citation> citations;

  bool get isUser => role == MessageRole.user;
}

class ChatStreamEvent {
  const ChatStreamEvent._({this.chunk, this.citations, this.isDone = false});

  final String? chunk;
  final List<Citation>? citations;
  final bool isDone;

  bool get hasChunk => chunk != null;
  bool get hasCitations => citations != null;

  factory ChatStreamEvent.chunk(String value) {
    return ChatStreamEvent._(chunk: value);
  }

  factory ChatStreamEvent.citations(List<Citation> citations) {
    return ChatStreamEvent._(citations: citations);
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
