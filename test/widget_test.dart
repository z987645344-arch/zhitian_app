import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zhitian_app/pages/chat_page.dart';
import 'package:zhitian_app/pages/history_page.dart';
import 'package:zhitian_app/providers/chat_provider.dart';
import 'package:zhitian_app/services/api_service.dart';

void main() {
  testWidgets('chat shows thinking bubble before first real chunk', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(ChatProvider(apiService: _FakeStreamingService())),
    );

    await tester.enterText(find.byType(TextField), '你好');
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

  testWidgets('connection error is displayed and sending state resets', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(apiService: _ErrorStreamingService());
    await tester.pumpWidget(_buildApp(provider));

    await tester.enterText(find.byType(TextField), '测试错误');
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

  testWidgets('history page loads records and clears current session', (
    WidgetTester tester,
  ) async {
    final provider = ChatProvider(apiService: _FakeStreamingService());
    final oldSessionId = provider.sessionId;
    final memoryService = _FakeMemoryService();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: HistoryPage(apiService: memoryService)),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('用户'), findsOneWidget);
    expect(find.text('知天'), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);
    expect(find.text('你好，我是知天'), findsOneWidget);
    expect(memoryService.loadedSessionId, oldSessionId);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump();

    expect(memoryService.clearedSessionId, oldSessionId);
    expect(provider.sessionId, isNot(oldSessionId));
    expect(provider.messages, isEmpty);
    expect(find.text('暂无历史记录'), findsOneWidget);
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
  Stream<String> chatStream({
    required String sessionId,
    required String message,
  }) async* {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final char in '真实回复正在逐字显示'.runes) {
      yield String.fromCharCode(char);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }
}

class _ErrorStreamingService implements ChatStreamingService {
  @override
  Stream<String> chatStream({
    required String sessionId,
    required String message,
  }) async* {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    yield ApiService.connectionErrorMessage;
  }
}

class _FakeMemoryService implements MemoryService {
  String? loadedSessionId;
  String? clearedSessionId;

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
}
