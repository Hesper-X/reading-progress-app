import 'dart:io';
import 'package:flutter/material.dart';

/// 通用书籍封面组件
///
/// - 有 coverPath 时显示真实图片
/// - 无 coverPath 时显示彩色渐变 + emoji 占位符
class BookCover extends StatelessWidget {
  final String? coverPath;
  final double width;
  final double height;
  final double borderRadius;
  final bool reading; // true=在读风格(📖珊瑚色), false=已读风格(📘蓝色)

  const BookCover({
    super.key,
    this.coverPath,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.reading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (coverPath != null && coverPath!.isNotEmpty) {
      // 有真实封面图片
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(coverPath!),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 图片加载失败时降级为占位符
            return _buildPlaceholder();
          },
        ),
      );
    }

    // 无封面 → 占位符
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: reading
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE3E3), Color(0xFFFFD3D3)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE3F2FD), Color(0xFFD3E8F5)],
              ),
      ),
      child: Center(
        child: Text(
          reading ? '📖' : '📘',
          style: TextStyle(fontSize: width * 0.47), // emoji 随卡片大小缩放
        ),
      ),
    );
  }
}
