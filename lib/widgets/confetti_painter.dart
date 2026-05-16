import 'dart:math';
import 'package:flutter/material.dart';

/// 撒花粒子
class ConfettiPiece {
  final double left; // 0-100 (百分比)
  final double sizeW;
  final double sizeH;
  final Color color;
  final double delay; // 秒
  final double duration; // 秒
  final bool isCircle; // 圆形还是矩形
  late final double startRotation;
  late final double endRotation;

  ConfettiPiece({
    required this.left,
    required this.sizeW,
    required this.sizeH,
    required this.color,
    required this.delay,
    required this.duration,
    required this.isCircle,
    double? startRotation,
    double? endRotation,
  }) {
    this.startRotation = startRotation ?? Random().nextDouble() * 360;
    this.endRotation = endRotation ?? startRotation! + 360 + Random().nextDouble() * 360;
  }
}

/// 撒花粒子绘制器
class ConfettiPainter extends CustomPainter {
  final List<ConfettiPiece> pieces;
  final double animationValue; // 0.0 ~ 1.0
  final double height;

  ConfettiPainter({
    required this.pieces,
    required this.animationValue,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = animationValue * 3.5; // 总动画时长约 3.5s

    for (final piece in pieces) {
      final localElapsed = elapsed - piece.delay;
      if (localElapsed < 0 || localElapsed > piece.duration) continue;

      final progress = localElapsed / piece.duration; // 0.0 ~ 1.0

      // Y 位置：从顶部 (-20) 落到底部 (height + 40)
      final y = lerpDouble(-20, height + 40, progress)!;

      // X 位置：轻微左右摆动
      final x = (piece.left / 100) * size.width + sin(progress * 4 * pi) * 15;

      // 旋转
      final rotation = piece.startRotation +
          (piece.endRotation - piece.startRotation) * progress;

      // 不透明度
      final opacity = progress < 0.85 ? 1.0 : (1.0 - (progress - 0.85) / 0.15);

      // 缩放
      final scale = lerpDouble(1.0, 0.4, progress)!;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation * pi / 180);
      canvas.scale(scale);

      final paint = Paint()..color = piece.color.withValues(alpha: opacity);

      if (piece.isCircle) {
        canvas.drawCircle(Offset.zero, piece.sizeW / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.sizeW,
              height: piece.sizeH,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;

  static double? lerpDouble(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }
}
