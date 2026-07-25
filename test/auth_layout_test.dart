// 认证页布局回归：宽窗口双栏、窄窗口单卡片，两种尺寸均不得溢出。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhitian_app/pages/login_page.dart';
import 'package:zhitian_app/pages/register_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpAt(WidgetTester tester, Widget page, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
  }

  // 真实Windows窗口尺寸与一个窄窗口尺寸，覆盖双栏与单卡片两条分支
  const desktop = Size(1580, 939);
  const narrow = Size(720, 900);

  testWidgets('login page renders without overflow at both widths', (
    tester,
  ) async {
    await pumpAt(tester, const LoginPage(), desktop);
    expect(tester.takeException(), isNull);
    // 宽窗口展示左侧品牌栏
    expect(find.text('安静、可靠的企业智能工作台'), findsOneWidget);
    expect(find.text('本地优先部署 · 数据不出企业边界'), findsOneWidget);

    await pumpAt(tester, const LoginPage(), narrow);
    expect(tester.takeException(), isNull);
    // 窄窗口收起品牌栏，只保留表单卡片
    expect(find.text('本地优先部署 · 数据不出企业边界'), findsNothing);
    expect(find.byKey(const Key('login_email')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
  });

  testWidgets('register page renders without overflow at both widths', (
    tester,
  ) async {
    await pumpAt(tester, const RegisterPage(), desktop);
    expect(tester.takeException(), isNull);
    expect(find.text('创建个人账号'), findsOneWidget);
    expect(find.text('返回登录'), findsOneWidget);

    await pumpAt(tester, const RegisterPage(), narrow);
    expect(tester.takeException(), isNull);
    for (final key in [
      'register_email',
      'register_password',
      'register_confirm_password',
      'register_verification_code',
      'register_send_code',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
  });
}
