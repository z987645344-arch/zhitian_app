import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhitian_app/models/chat_session.dart';
import 'package:zhitian_app/models/file_preview.dart';
import 'package:zhitian_app/models/message.dart';
import 'package:zhitian_app/models/pending_attachment.dart';
import 'package:zhitian_app/models/tool_conversion.dart';
import 'package:zhitian_app/models/user_file.dart';
import 'package:zhitian_app/pages/chat_page.dart';
import 'package:zhitian_app/pages/files_page.dart';
import 'package:zhitian_app/pages/history_page.dart';
import 'package:zhitian_app/providers/chat_provider.dart';
import 'package:zhitian_app/services/api_service.dart';
import 'package:zhitian_app/widgets/message_bubble.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('chat shows thinking bubble before first real chunk', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(ChatProvider(apiService: _FakeStreamingService())),
    );

    await tester.enterText(find.byType(TextField), '你好');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('你好'), findsOneWidget);
    expect(find.text('思考中'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('▌'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('思考中'), findsNothing);
    expect(find.text('▌'), findsOneWidget);
    expect(find.textContaining('真实'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('▌'), findsNothing);
    expect(find.textContaining('真实回复正在逐字显示'), findsOneWidget);
  });

  testWidgets('new chat clears messages and regenerates session id', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(apiService: _FakeStreamingService());
    final oldSessionId = provider.sessionId;
    await tester.pumpWidget(_buildApp(provider));

    await tester.enterText(find.byType(TextField), '第一轮');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('第一轮'), findsOneWidget);
    expect(provider.messages, isNotEmpty);

    await tester.tap(find.byIcon(Icons.add_comment));
    await tester.pump();

    expect(provider.messages, isEmpty);
    expect(provider.sessionId, isNot(oldSessionId));
    expect(provider.isThinking, isFalse);
    expect(provider.isSending, isFalse);
    expect(find.text('开始对话'), findsOneWidget);
  });

  testWidgets('chat mode defaults to fast and switches to expert', (
    WidgetTester tester,
  ) async {
    final service = _ModeStreamingService();
    final provider = ChatProvider(apiService: service);
    await tester.pumpWidget(_buildApp(provider));

    expect(provider.mode, 'fast');
    await tester.enterText(find.byType(TextField), '快速消息');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(service.modes, ['fast']);

    await tester.tap(find.text('专家'));
    await tester.pump();
    expect(provider.mode, 'expert');

    provider.newChat();
    expect(provider.mode, 'expert');
    await tester.enterText(find.byType(TextField), '专家消息');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(service.modes, ['fast', 'expert']);
  });

  testWidgets('chat toolbar opens the independent toolbox page', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(apiService: _FakeStreamingService());
    await tester.pumpWidget(_buildApp(provider));

    await tester.tap(find.byIcon(Icons.build_outlined));
    await tester.pumpAndSettle();

    expect(find.text('工具箱'), findsOneWidget);
    expect(find.text('开始转换'), findsOneWidget);
    expect(find.text('PDF合并'), findsOneWidget);
    expect(find.text('PDF拆分'), findsOneWidget);
  });

  testWidgets('file library lists files and confirms deletion', (
    WidgetTester tester,
  ) async {
    final service = _FakeFileLibraryService();
    await tester.pumpWidget(MaterialApp(home: FilesPage(apiService: service)));
    await tester.pumpAndSettle();

    expect(find.text('我的文件'), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('确定删除'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(service.deletedIds, ['file-1']);
    expect(find.text('report.pdf'), findsNothing);
  });

  testWidgets('file library opens preview page and shows truncation notice', (
    WidgetTester tester,
  ) async {
    final service = _FakeFileLibraryService();
    await tester.pumpWidget(MaterialApp(home: FilesPage(apiService: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('预览'));
    await tester.pumpAndSettle();

    expect(find.text('preview content'), findsOneWidget);
    expect(find.text('内容较长，已截断显示'), findsOneWidget);
  });

  testWidgets('connection error is displayed and sending state resets', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(apiService: _ErrorStreamingService());
    await tester.pumpWidget(_buildApp(provider));

    await tester.enterText(find.byType(TextField), '测试错误');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('思考中'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.text('思考中'), findsNothing);
    expect(find.text(ApiService.connectionErrorMessage), findsOneWidget);
    expect(provider.isThinking, isFalse);
    expect(provider.isSending, isFalse);
  });

  testWidgets('assistant message shows citations after stream completes', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(apiService: _CitationStreamingService());
    await tester.pumpWidget(_buildApp(provider));

    await tester.enterText(find.byType(TextField), '查文档');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('引用来源 1'), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('文档答案'), findsOneWidget);
    expect(find.text('引用来源 1'), findsOneWidget);
    expect(find.text('测试文档.md · 片段 1'), findsNothing);

    await tester.tap(find.text('引用来源 1'));
    await tester.pump();

    expect(find.text('测试文档.md · 片段 1'), findsOneWidget);
  });
  testWidgets('assistant message shows in-memory decision reasoning', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(apiService: _ReasoningStreamingService());
    await tester.pumpWidget(_buildApp(provider));

    await tester.enterText(find.byType(TextField), '查资料');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('问题涉及企业内部信息，需要先检索知识库'), findsOneWidget);
    expect(find.text('资料回答'), findsOneWidget);
    expect(provider.messages.last.reasoning, isNotNull);
  });
  testWidgets('restored user message shows attachment filename chips', (
    WidgetTester tester,
  ) async {
    final message = Message.fromHistory({
      'role': 'user',
      'content': '',
      'attachment_ids': ['file-1'],
      'attachment_filenames': ['history.pdf'],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessageBubble(message: message)),
      ),
    );

    expect(find.text('history.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
  });
  testWidgets(
    'pure attachment bubble falls back to a visible attachment chip',
    (WidgetTester tester) async {
      final message = Message(
        role: MessageRole.user,
        content: '',
        attachmentIds: ['attachment-without-filename'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MessageBubble(message: message)),
        ),
      );

      expect(find.text('附件 1'), findsOneWidget);
      expect(find.byType(MessageBubble), findsOneWidget);
    },
  );
  testWidgets('history page loads records and clears current session', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(apiService: _FakeStreamingService());
    final oldSessionId = provider.sessionId;
    final memoryService = _FakeMemoryService(oldSessionId);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: HistoryPage(apiService: memoryService)),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('第一轮对话'), findsOneWidget);
    expect(find.textContaining('2 条消息'), findsOneWidget);

    await tester.tap(find.byTooltip('清空历史'));
    await tester.pump();
    await tester.pump();

    expect(memoryService.clearedSessionId, oldSessionId);
    expect(provider.sessionId, isNot(oldSessionId));
    expect(provider.messages, isEmpty);
    expect(find.text('暂无历史记录'), findsOneWidget);
  });

  testWidgets('history session can be renamed and fully deleted', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(
      apiService: _FakeStreamingService(),
      initialSessionId: 'managed-session',
    );
    final memoryService = _FakeMemoryService('managed-session');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: HistoryPage(apiService: memoryService)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '项目讨论');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('项目讨论'), findsOneWidget);
    expect(memoryService.renamedDisplayName, '项目讨论');

    await tester.tap(find.byTooltip('删除会话'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(memoryService.deletedSessionId, 'managed-session');
    expect(find.text('暂无历史记录'), findsOneWidget);
    expect(provider.sessionId, isNot('managed-session'));
  });
}

Widget _buildApp(ChatProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: const MaterialApp(home: ChatPage()),
  );
}

class _FakeStreamingService implements ChatStreamingService {
  @override
  Future<ChatAttachmentUpload> uploadChatAttachment(
    String sessionId,
    File file,
  ) => throw UnimplementedError();

  @override
  Stream<ChatStreamEvent> chatStream({
    required String sessionId,
    required String message,
    required String mode,
    List<String> attachmentIds = const [],
  }) async* {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final char in '真实回复正在逐字显示'.runes) {
      yield ChatStreamEvent.chunk(String.fromCharCode(char));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }
}

class _ErrorStreamingService implements ChatStreamingService {
  @override
  Future<ChatAttachmentUpload> uploadChatAttachment(
    String sessionId,
    File file,
  ) => throw UnimplementedError();

  @override
  Stream<ChatStreamEvent> chatStream({
    required String sessionId,
    required String message,
    required String mode,
    List<String> attachmentIds = const [],
  }) async* {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    yield ChatStreamEvent.chunk(ApiService.connectionErrorMessage);
  }
}

class _CitationStreamingService implements ChatStreamingService {
  @override
  Future<ChatAttachmentUpload> uploadChatAttachment(
    String sessionId,
    File file,
  ) => throw UnimplementedError();

  @override
  Stream<ChatStreamEvent> chatStream({
    required String sessionId,
    required String message,
    required String mode,
    List<String> attachmentIds = const [],
  }) async* {
    for (final char in '文档答案'.runes) {
      yield ChatStreamEvent.chunk(String.fromCharCode(char));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    yield ChatStreamEvent.citations([
      const Citation(
        source: '测试文档.md',
        docId: 'doc-1',
        chunkIndex: 0,
        score: 0.72,
      ),
    ]);
    yield ChatStreamEvent.done();
  }
}

class _ReasoningStreamingService implements ChatStreamingService {
  @override
  Future<ChatAttachmentUpload> uploadChatAttachment(
    String sessionId,
    File file,
  ) => throw UnimplementedError();

  @override
  Stream<ChatStreamEvent> chatStream({
    required String sessionId,
    required String message,
    required String mode,
    List<String> attachmentIds = const [],
  }) async* {
    yield ChatStreamEvent.reasoning('问题涉及企业内部信息，需要先检索知识库');
    yield ChatStreamEvent.chunk('资料回答');
    yield ChatStreamEvent.done();
  }
}

class _ModeStreamingService implements ChatStreamingService {
  final List<String> modes = [];

  @override
  Future<ChatAttachmentUpload> uploadChatAttachment(
    String sessionId,
    File file,
  ) => throw UnimplementedError();

  @override
  Stream<ChatStreamEvent> chatStream({
    required String sessionId,
    required String message,
    required String mode,
    List<String> attachmentIds = const [],
  }) async* {
    modes.add(mode);
    yield ChatStreamEvent.chunk('ok');
    yield ChatStreamEvent.done();
  }
}

class _FakeFileLibraryService implements FileLibraryService {
  final List<String> deletedIds = [];

  @override
  Future<List<UserFile>> listFiles() async => [
    UserFile(
      fileId: 'file-1',
      originalFilename: 'report.pdf',
      format: 'pdf',
      sourceType: 'generated',
      sizeBytes: 1024,
      createdAt: DateTime(2026, 7, 15),
    ),
  ];

  @override
  Future<FilePreview> previewFile(String fileId) async => const FilePreview(
    fileId: 'file-1',
    filename: 'report.pdf',
    format: 'pdf',
    content: 'preview content',
    truncated: true,
  );

  @override
  Future<ToolConversionDownload> downloadFile(
    String fileId, {
    required String fallbackFilename,
  }) async =>
      ToolConversionDownload(filename: fallbackFilename, bytes: Uint8List(0));

  @override
  Future<void> deleteFile(String fileId) async {
    deletedIds.add(fileId);
  }
}

class _FakeMemoryService implements MemoryService {
  _FakeMemoryService(this.sessionId);

  final String sessionId;
  String? loadedSessionId;
  String? clearedSessionId;
  String? renamedSessionId;
  String? renamedDisplayName;
  String? deletedSessionId;

  @override
  Future<List<ChatSessionSummary>> getSessions() async => [
    ChatSessionSummary(
      sessionId: sessionId,
      title: '第一轮对话',
      lastActive: '2026-06-30T10:00:01',
      messageCount: 2,
    ),
  ];

  @override
  Future<List<Map>> getHistory(String sessionId) async {
    loadedSessionId = sessionId;
    return [
      {'role': 'user', 'content': '你好', 'timestamp': '2026-06-30T10:00:00'},
      {
        'role': 'assistant',
        'content': '你好，我是知天',
        'timestamp': '2026-06-30T10:00:01',
      },
    ];
  }

  @override
  Future<bool> clearHistory(String sessionId) async {
    clearedSessionId = sessionId;
    return true;
  }

  @override
  Future<String?> renameSession(String sessionId, String? displayName) async {
    renamedSessionId = sessionId;
    renamedDisplayName = displayName;
    return displayName;
  }

  @override
  Future<bool> deleteSession(String sessionId) async {
    deletedSessionId = sessionId;
    return true;
  }
}
