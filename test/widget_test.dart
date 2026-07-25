import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';

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
import 'package:zhitian_app/pages/register_page.dart';
import 'package:zhitian_app/providers/chat_provider.dart';
import 'package:zhitian_app/services/api_service.dart';
import 'package:zhitian_app/widgets/message_bubble.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 认证页是桌面端表单，默认800x600测试窗口装不下完整表单会导致按钮落在视口外，
  /// 按真实Windows桌面尺寸测试才与实际使用一致。
  void useDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('customer registration validates email and matching passwords', (
    WidgetTester tester,
  ) async {
    useDesktopViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'invalid-email',
    );
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'Password123!',
    );
    await tester.enterText(
      find.byKey(const Key('register_confirm_password')),
      'Different123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, '注册'));
    await tester.pump();
    expect(find.text('请输入有效的邮箱地址'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register_email')),
      'user@example.test',
    );
    await tester.tap(find.widgetWithText(FilledButton, '注册'));
    await tester.pump();
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
  });

  testWidgets('customer registration requires a verification code', (
    WidgetTester tester,
  ) async {
    useDesktopViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'user@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'Password123!',
    );
    await tester.enterText(
      find.byKey(const Key('register_confirm_password')),
      'Password123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, '注册'));
    await tester.pump();
    expect(find.text('请输入邮箱验证码'), findsOneWidget);
  });

  testWidgets('sending the register code starts a 180 second cooldown', (
    WidgetTester tester,
  ) async {
    useDesktopViewport(tester);
    final service = _FakeRegisterService();
    await tester.pumpWidget(
      MaterialApp(home: RegisterPage(apiService: service)),
    );
    // 邮箱无效时不发起请求
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'invalid-email',
    );
    await tester.tap(find.byKey(const Key('register_send_code')));
    await tester.pump();
    expect(service.sentEmails, isEmpty);
    expect(find.text('请输入有效的邮箱地址'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register_email')),
      'user@example.test',
    );
    await tester.tap(find.byKey(const Key('register_send_code')));
    await tester.pump();
    expect(service.sentEmails, ['user@example.test']);
    expect(find.text('验证码已发送，请查收邮箱'), findsOneWidget);
    // 后端customer_register冷却为180秒，按钮进入倒计时且不可再次点击
    expect(find.text('180s'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('register_send_code')),
    );
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('179s'), findsOneWidget);

    // 卸载页面触发dispose，取消倒计时Timer
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('compact navigation rail does not overflow at desktop width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(785, 1137);
    tester.view.devicePixelRatio = 1.25;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildApp(ChatProvider(apiService: _FakeStreamingService())),
    );
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    final details = exception is FlutterError
        ? exception.diagnostics.map((node) => node.toString()).join('\n')
        : '';
    expect(exception, isNull, reason: details);
  });

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

  testWidgets(
    'workspace navigation replaces center content without new route',
    (WidgetTester tester) async {
      final provider = ChatProvider(apiService: _FakeStreamingService());
      await tester.pumpWidget(_buildApp(provider));

      await tester.tap(find.byIcon(Icons.build_outlined));
      await tester.pumpAndSettle();

      expect(find.text('工具箱'), findsNWidgets(2));
      expect(find.text('开始转换'), findsOneWidget);
      expect(find.text('PDF合并'), findsOneWidget);
      expect(find.text('PDF拆分'), findsOneWidget);
      expect(Navigator.of(tester.element(find.text('开始转换'))).canPop(), isFalse);

      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('开始对话'), findsOneWidget);
    },
  );

  testWidgets('recent session supports double-click rename and hover delete', (
    WidgetTester tester,
  ) async {
    final service = _WorkspaceMemoryService();
    final provider = ChatProvider(
      apiService: service,
      initialSessionId: 'recent-session',
    );
    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    final title = find.descendant(
      of: find.byType(GestureDetector),
      matching: find.text('第一轮对话'),
    );
    expect(title, findsOneWidget);
    await tester.tap(title);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(find.text('重命名会话'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '新会话名称',
    );
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('新会话名称'), findsWidgets);
    expect(service.renamedDisplayName, '新会话名称');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('2')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('删除会话'), findsOneWidget);
    await tester.tap(find.byTooltip('删除会话'));
    await tester.pumpAndSettle();
    expect(find.textContaining('确定删除'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.text('新会话名称'), findsWidgets);

    await tester.tap(find.byTooltip('删除会话'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(service.deletedSessionId, 'recent-session');
    expect(find.text('新会话名称'), findsNothing);
    await mouse.removePointer();
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

class _FakeRegisterService extends ApiService {
  final List<String> sentEmails = [];

  @override
  Future<void> sendCustomerRegisterCode({required String email}) async {
    sentEmails.add(email);
  }
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

class _WorkspaceMemoryService extends _FakeStreamingService
    implements MemoryService {
  String? renamedDisplayName;
  String? deletedSessionId;

  @override
  Future<List<ChatSessionSummary>> getSessions() async => [
    ChatSessionSummary(
      sessionId: 'recent-session',
      title: '第一轮对话',
      lastActive: '2026-07-19T10:00:00',
      messageCount: 2,
    ),
  ];

  @override
  Future<List<Map>> getHistory(String sessionId) async => [];

  @override
  Future<bool> clearHistory(String sessionId) async => true;

  @override
  Future<String?> renameSession(String sessionId, String? displayName) async {
    renamedDisplayName = displayName;
    return displayName;
  }

  @override
  Future<bool> deleteSession(String sessionId) async {
    deletedSessionId = sessionId;
    return true;
  }
}
