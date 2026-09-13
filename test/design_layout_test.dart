import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhitian_app/theme/app_theme.dart';
import 'package:zhitian_app/pages/login_page.dart';
import 'package:zhitian_app/pages/register_page.dart';
import 'package:zhitian_app/pages/backend_setup_page.dart';
import 'package:zhitian_app/pages/chat_page.dart';
import 'package:zhitian_app/pages/settings_page.dart';
import 'package:zhitian_app/pages/files_page.dart';
import 'package:zhitian_app/pages/history_page.dart';
import 'package:zhitian_app/pages/toolbox_page.dart';
import 'package:zhitian_app/providers/chat_provider.dart';
import 'package:zhitian_app/models/message.dart';
import 'package:zhitian_app/widgets/message_bubble.dart';
import 'package:zhitian_app/widgets/chat_composer.dart';
import 'package:zhitian_app/models/pending_attachment.dart';
import 'support/design_fixtures.dart';

void main() {
  testWidgets('failed attachment exposes recovery text without hover', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            isSending: false,
            pendingAttachments: const [
              PendingAttachment(
                attachmentId: 'failed-local',
                filename: '会议资料.md',
                status: AttachmentUploadStatus.failed,
                errorMessage: '网络不可达',
              ),
            ],
            hasUploadingAttachments: false,
            hasSuccessfulAttachments: false,
            onAddAttachment: (_) async {},
            onRemoveAttachment: (_) {},
            onSend: () {},
          ),
        ),
      ),
    );
    expect(find.text('会议资料.md：上传失败。网络不可达。移除后可重新添加。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [375.0, 1280.0]) {
    testWidgets('dark pages remain usable at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = DesignService();
      final provider = ChatProvider(apiService: api);
      final pages = <Widget>[
        LoginPage(apiService: api),
        RegisterPage(apiService: api),
        BackendSetupPage(apiService: api, nextPage: const LoginPage()),
        const ChatPage(),
        SettingsPage(apiService: api),
        FilesPage(apiService: api),
        HistoryPage(apiService: api),
        ToolboxPage(apiService: api),
      ];
      for (final page in pages) {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(theme: AppTheme.dark, home: page),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} at $width',
        );
        expect(find.byType(Scaffold), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  }
  testWidgets('assistant error has status semantics and no answer text', (
    tester,
  ) async {
    final message = Message(role: MessageRole.assistant, content: '')
      ..displayError = '登录已过期，请重新登录';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: MessageBubble(message: message)),
      ),
    );
    expect(find.text('本次回答未完成'), findsOneWidget);
    expect(find.text('登录已过期，请重新登录'), findsOneWidget);
    expect(message.content, isEmpty);
    final statuses = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((widget) => widget.properties.liveRegion == true);
    expect(statuses, isNotEmpty);
  });
}
