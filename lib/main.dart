import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/chat_page.dart';
import 'pages/login_page.dart';
import 'providers/chat_provider.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(ApiService.authTokenKey)?.trim();
  runApp(ZhitianApp(isLoggedIn: token != null && token.isNotEmpty));
}

class ZhitianApp extends StatelessWidget {
  const ZhitianApp({super.key, required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: MaterialApp(
        title: '知天',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          useMaterial3: true,
        ),
        home: isLoggedIn ? const ChatPage() : const LoginPage(),
      ),
    );
  }
}
