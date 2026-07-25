import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 认证页统一外壳。
///
/// 宽窗口（>=960px）按企业设计的 Fixed-Fluid 结构展开为左品牌栏 + 右表单卡片，
/// 填满桌面画布；窄窗口退化为居中单卡片，保持既有可用性。
/// 登录与注册共用此外壳，避免两页视觉规范各自漂移。
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
    this.footer,
  });

  /// 表单区标题，如"登录"、"创建个人账号"。
  final String title;

  /// 标题下方的一句话说明。
  final String subtitle;

  /// 表单内容，按 4px 基线节奏自行控制间距。
  final List<Widget> children;

  /// 非空时在表单卡片左上角显示返回入口。
  final VoidCallback? onBack;

  /// 卡片底部的次级操作区（注册入口 / 返回登录）。
  final Widget? footer;

  static const double _brandPanelWidth = 420;
  static const double _formMaxWidth = 400;
  static const double _wideBreakpoint = 960;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            if (!wide) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: _formCard(context, compact: true)),
                ),
              );
            }
            return Row(
              children: [
                const _BrandPanel(width: _brandPanelWidth),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: _formCard(context, compact: false)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _formCard(BuildContext context, {required bool compact}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _formMaxWidth),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 窄窗口没有左品牌栏，卡片内补一个精简品牌头。
            // Column为stretch，固定尺寸的品牌块必须用Align包住才不会被拉成整行宽。
            if (compact) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: _BrandMark(size: 44, radius: 12, iconSize: 24),
              ),
              const SizedBox(height: 16),
            ],
            if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onBack,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('返回登录'),
                ),
              ),
            if (onBack != null) const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 1.33,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ...children,
            if (footer != null) ...[
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 左侧品牌栏：用 tonal layering 与背景区分，不使用阴影。
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.width});

  final double width;

  static const List<(IconData, String, String)> _highlights = [
    (Icons.verified_outlined, '可验证回答', '企业知识库检索结果附带引用来源'),
    (Icons.bolt_outlined, '快速 / 专家双模式', '日常问答低延迟，复杂任务可联网分解'),
    (Icons.folder_open_outlined, '统一文件工作台', '附件阅读、格式转换与个人文件库'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandMark(size: 52, radius: 14, iconSize: 28),
          const SizedBox(height: 24),
          const Text(
            '知天',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '安静、可靠的企业智能工作台',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 28),
          for (final (icon, title, desc) in _highlights) ...[
            _HighlightRow(icon: icon, title: title, description: desc),
            const SizedBox(height: 20),
          ],
          const Spacer(),
          const Text(
            '本地优先部署 · 数据不出企业边界',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({
    required this.size,
    required this.radius,
    required this.iconSize,
  });

  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.auto_awesome_outlined,
        color: AppColors.primary,
        size: iconSize,
      ),
    );
  }
}

/// 表单字段外壳：字段标签独立成行（企业表单惯例），而非浮动 label。
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.trailing,
  });

  final String label;
  final Widget child;

  /// 字段下方的补充说明，如密码强度要求。
  final String? hint;

  /// 输入框右侧的同行操作，如"发送验证码"。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.38,
          ),
        ),
        const SizedBox(height: 6),
        if (trailing == null)
          child
        else
          Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: 8),
              trailing!,
            ],
          ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint!,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// 统一的输入框样式：白底 + 1px 边框，聚焦时描边转为主色。
InputDecoration authInputDecoration({
  required String hintText,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
    suffixIcon: suffixIcon,
    counterText: '',
    isDense: true,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.fromLTRB(0, 13, 12, 13),
    border: _authBorder(AppColors.border),
    enabledBorder: _authBorder(AppColors.border),
    focusedBorder: _authBorder(AppColors.primary, width: 1.5),
    errorBorder: _authBorder(AppColors.error),
    focusedErrorBorder: _authBorder(AppColors.error, width: 1.5),
  );
}

OutlineInputBorder _authBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// 行内提示条：错误用 error 容器色，成功/中性提示用主色浅容器。
class AuthMessage extends StatelessWidget {
  const AuthMessage({super.key, required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, height: 1.46),
            ),
          ),
        ],
      ),
    );
  }
}
