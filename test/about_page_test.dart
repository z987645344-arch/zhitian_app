import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhitian_app/pages/about_page.dart';
import 'package:zhitian_app/pages/settings_page.dart';
import 'package:zhitian_app/theme/app_theme.dart';

import 'support/design_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('版本读取现有pubspec资源而非硬编码', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final expected = RegExp(
      r'^version:\s*([^\s#]+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(await loadApplicationVersion(), expected);
    expect(applicationCopyright, '© 2026 知了 · 保留所有权利');
  });

  for (final width in [375.0, 1280.0]) {
    testWidgets('设置可进入关于及开源许可且无溢出 $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // 真实资源读取放在runAsync，不能在widget测试的假时钟中等待磁盘I/O。
      final version = await tester.runAsync(loadApplicationVersion);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: SettingsPage(apiService: DesignService()),
        ),
      );
      await tester.pumpAndSettle();
      final about = find.byKey(const Key('open_about'));
      await tester.ensureVisible(about);
      await tester.tap(about);
      await tester.pumpAndSettle();
      // 等关于页发起的资源Future在真实事件循环完成，再验证界面文本。
      await tester.runAsync(loadApplicationVersion);
      await tester.pumpAndSettle();
      expect(find.byType(AboutPage), findsOneWidget);
      expect(find.text('知天'), findsOneWidget);
      expect(find.text(applicationCopyright), findsOneWidget);
      expect(find.text('版本 $version'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('open_source_licenses')));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text(applicationCopyright), findsWidgets);
      expect(find.text(version!), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
