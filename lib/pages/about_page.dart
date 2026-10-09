import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

const applicationCopyright = '© 2026 知了 · 保留所有权利。';

/// 使用现有版本唯一来源，不另存一个可能失配的版本常量。
Future<String> loadApplicationVersion() async {
  final manifest = await rootBundle.loadString('pubspec.yaml');
  final match = RegExp(
    r'^version:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(manifest);
  if (match == null) throw const FormatException('应用版本信息不可用');
  return match.group(1)!;
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final Future<String> _version = loadApplicationVersion();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('关于')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const Text(
              '知天',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: _version,
              builder: (context, snapshot) => Text(
                snapshot.hasError
                    ? '版本信息暂不可用'
                    : '版本 ${snapshot.data ?? '正在读取…'}',
                key: const Key('application_version'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              applicationCopyright,
              style: TextStyle(color: AppColors.textMuted, height: 1.6),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('open_source_licenses'),
              onPressed: () async {
                final version = await _version.catchError(
                  (Object _) => '版本信息暂不可用',
                );
                if (!context.mounted) return;
                showLicensePage(
                  context: context,
                  applicationName: '知天',
                  applicationVersion: version,
                  applicationLegalese: applicationCopyright,
                );
              },
              icon: const Icon(Icons.description_outlined),
              label: const Text('开源许可'),
            ),
          ],
        ),
      ),
    ),
  );
}
