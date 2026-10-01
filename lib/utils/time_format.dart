/// API时间统一按UTC解析、按设备本地时区显示；兼容旧的无时区响应。
DateTime? parseApiTimestamp(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final raw = value.trim().replaceFirst(' ', 'T');
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}').hasMatch(raw)) {
    return null;
  }
  final tagged = RegExp(
    r'(Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw);
  return DateTime.tryParse(tagged ? raw : '${raw}Z')?.toUtc();
}

String formatLocalTime(String? value) {
  final date = parseApiTimestamp(value)?.toLocal();
  if (date == null) return '时间未知';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
