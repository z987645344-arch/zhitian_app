import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhitian_app/main.dart';
import 'package:zhitian_app/pages/backend_setup_page.dart';
import 'package:zhitian_app/pages/login_page.dart';
import 'package:zhitian_app/pages/register_page.dart';
import 'package:zhitian_app/providers/chat_provider.dart';
import 'package:zhitian_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('backend URL normalization enforces HTTPS outside localhost', () {
    expect(ApiService.defaultBackendUrl, 'http://localhost/api');
    expect(
      ApiService.normalizeBackendUrl('api.example.test/'),
      'https://api.example.test',
    );
    expect(
      ApiService.normalizeBackendUrl('localhost:8000/'),
      'http://localhost:8000',
    );
    expect(
      ApiService.normalizeBackendUrl('localhost/api/'),
      'http://localhost/api',
    );
    expect(ApiService.isLegacyLocalDebugUrl('localhost:8000'), isTrue);
    expect(ApiService.isLegacyLocalDebugUrl('localhost/api'), isFalse);
    expect(
      () => ApiService.normalizeBackendUrl('http://api.example.test'),
      throwsFormatException,
    );
    expect(
      () => ApiService.normalizeBackendUrl(
        'https://user:pass@api.example.test?secret=1',
      ),
      throwsFormatException,
    );
  });

  testWidgets('first launch asks for backend URL and persists it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ApiService.authTokenKey: 'token-from-an-unconfigured-server',
      ApiService.chatSessionIdKey: 'old-session',
    });
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ZhitianApp(isLoggedIn: false, hasConfiguredBackend: false),
    );
    expect(find.text('连接企业服务'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('backend_setup_url')),
      'localhost/api/',
    );
    await tester.tap(find.byKey(const Key('backend_setup_continue')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ApiService.backendUrlKey), 'http://localhost/api');
    expect(prefs.getString(ApiService.authTokenKey), isNull);
    expect(prefs.getString(ApiService.chatSessionIdKey), isNull);
    expect(find.text('安全登录'), findsOneWidget);
  });

  testWidgets('login can replace a legacy Compose address before auth', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ApiService.backendUrlKey: ApiService.legacyLocalDebugBackendUrl,
      ApiService.authTokenKey: 'old-token',
      ApiService.chatSessionIdKey: 'old-session',
    });
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('检测到旧的本机调试地址'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('login_server_settings')));
    await tester.tap(find.byKey(const Key('login_server_settings')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('backend_setup_url')),
    );
    expect(field.controller!.text, ApiService.legacyLocalDebugBackendUrl);

    await tester.enterText(
      find.byKey(const Key('backend_setup_url')),
      ApiService.composeBackendUrl,
    );
    await tester.tap(find.byKey(const Key('backend_setup_continue')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(ApiService.backendUrlKey),
      ApiService.composeBackendUrl,
    );
    expect(prefs.getString(ApiService.authTokenKey), isNull);
    expect(prefs.getString(ApiService.chatSessionIdKey), isNull);
    expect(find.text('当前服务器：${ApiService.composeBackendUrl}'), findsOneWidget);
  });

  testWidgets('register exposes server settings before sending a code', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ApiService.backendUrlKey: ApiService.composeBackendUrl,
    });
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('register_server_settings')),
    );
    await tester.tap(find.byKey(const Key('register_server_settings')));
    await tester.pumpAndSettle();

    expect(find.text('连接企业服务'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('backend_setup_url')),
    );
    expect(field.controller!.text, ApiService.composeBackendUrl);
  });

  testWidgets('invalid remote HTTP address remains on setup page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BackendSetupPage(nextPage: SizedBox(key: Key('next_page'))),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('backend_setup_url')),
      'http://api.example.test',
    );
    await tester.tap(find.byKey(const Key('backend_setup_continue')));
    await tester.pump();

    expect(find.text('远程服务必须使用 HTTPS；HTTP 仅允许本机地址'), findsOneWidget);
    expect(find.byKey(const Key('next_page')), findsNothing);
  });

  test('certificate failures return a clear Chinese message', () async {
    final service = ApiService(clientFactory: _CertificateFailureClient.new);
    final result = await service.checkBackendUrl('https://api.example.test');

    expect(result.status, 'certificate_error');
    expect(result.message, contains('证书验证失败'));
    expect(result.message, isNot(contains('HandshakeException')));
  });

  test('fast or expert mode persists as a local setting', () async {
    final provider = ChatProvider(initialMode: 'fast');
    provider.setMode('expert');
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ApiService.chatModeKey), 'expert');
    expect(ChatProvider(initialMode: 'expert').mode, 'expert');
  });
}

class _CertificateFailureClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw HandshakeException('CERTIFICATE_VERIFY_FAILED');
  }
}
