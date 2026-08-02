import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/backend_setup_page.dart';
import 'pages/chat_page.dart';
import 'pages/login_page.dart';
import 'providers/chat_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(ApiService.authTokenKey)?.trim();
  final sessionId = prefs.getString(ApiService.chatSessionIdKey)?.trim();
  final backendUrl = prefs.getString(ApiService.backendUrlKey)?.trim();
  final savedMode = prefs.getString(ApiService.chatModeKey)?.trim();
  runApp(
    ZhitianApp(
      isLoggedIn: token != null && token.isNotEmpty,
      initialSessionId: sessionId,
      initialMode: savedMode,
      hasConfiguredBackend: ApiService.isValidBackendUrl(backendUrl),
    ),
  );
}

class ZhitianApp extends StatelessWidget {
  const ZhitianApp({
    super.key,
    required this.isLoggedIn,
    this.initialSessionId,
    this.initialMode,
    this.hasConfiguredBackend = true,
  });

  final bool isLoggedIn;
  final String? initialSessionId;
  final String? initialMode;
  final bool hasConfiguredBackend;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(
        initialSessionId: initialSessionId,
        initialMode: initialMode,
      ),
      child: MaterialApp(
        title: '知天',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: hasConfiguredBackend
            ? (isLoggedIn ? const ChatPage() : const LoginPage())
            : const BackendSetupPage(nextPage: LoginPage()),
      ),
    );
  }
}
