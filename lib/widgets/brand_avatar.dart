import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 品牌头像标记：琥珀圆角底上的 OC 头像，替代原先的圆形"知"字。
///
/// 头像以 base64 内嵌（128px WebP，约 7KB），不新增 pubspec 资源声明。
class BrandAvatar extends StatelessWidget {
  const BrandAvatar({super.key, required this.size});

  final double size;

  static final Uint8List _bytes = base64Decode(_avatarWebp);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [AppColors.primarySoft, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: size * 0.5,
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Image.memory(
          _bytes,
          width: size * 0.92,
          height: size * 0.92,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

const String _avatarWebp =
    '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';
