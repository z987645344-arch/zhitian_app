import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhitian_app/models/user_file.dart';
import 'package:zhitian_app/providers/chat_provider.dart';
import 'package:zhitian_app/utils/time_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Asia/Shanghai: 新旧时间格式都显示10:46，保留显式偏移', () {
    // CI(Linux)使用TZ=Asia/Shanghai；Windows CRT使用等价的TZ=CST-8。
    expect(DateTime(2026, 9, 30).timeZoneOffset, const Duration(hours: 8));
    for (final value in [
      '2026-09-30T02:46:13Z',
      '2026-09-30T02:46:13',
      '2026-09-30 02:46:13',
      '2026-09-30T10:46:13+08:00',
    ]) {
      expect(formatLocalTime(value), '2026-09-30 10:46');
      expect(parseApiTimestamp(value)!.isUtc, isTrue);
    }
    expect(formatLocalTime('invalid'), '时间未知');
    expect(formatLocalTime(null), '时间未知');
    expect(formatLocalTime('2026-09-30T20:46:13Z'), '2026-10-01 04:46');
  });

  test('文件模型兼容旧的UTC-naive响应', () {
    final file = UserFile.fromJson({'created_at': '2026-09-30T02:46:13'});
    expect(file.createdAt, DateTime.utc(2026, 9, 30, 2, 46, 13));
  });

  test('本地新建会话保存UTC，而非设备本地时间', () {
    final provider = ChatProvider();
    provider.newChat();
    expect(provider.sessions.first.lastActive, endsWith('Z'));
    provider.dispose();
  });
}
