import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../routes/app_routes.dart';

/// 启动过渡页（无动画，保持与 Android 原生启动图 100% 一致）
/// 等待数据加载完成后自动跳转首页
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // 固定 2 秒后跳转首页（覆盖 Flutter 引擎初始化 + 首页首帧渲染）
    Future.delayed(const Duration(milliseconds: 2000), _navigateToHome);
  }

  void _navigateToHome() {
    if (_navigated) return;
    _navigated = true;
    if (mounted && context.mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF6B6B),
              Color(0xFFFF8E8E),
              Color(0xFFFFA8A8),
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo 容器（140x140）
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _LaunchProgressPainter(),
                      child: const Center(
                        child: _LaunchIcon(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '读书进度条',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '把你读完的书，变成一种生命的进度',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            // 底部版本号
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                'Version ${AppConstants.appVersion}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0x80FFFFFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 启动页环形进度条（65% 示例）— 保持与原 SplashPage 一致
class _LaunchProgressPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 48.0;
    final strokeWidth = 7.0;

    final remainingPaint = Paint()
      ..color = const Color(0xFFE9ECEF)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, remainingPaint);

    final completedPaint = Paint()
      ..color = const Color(0xFF51CF66)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 3.14159 * 2 * 0.65;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      sweepAngle,
      false,
      completedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 启动页书架图标
class _LaunchIcon extends StatelessWidget {
  const _LaunchIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _BookshelfPainter(),
      ),
    );
  }
}

class _BookshelfPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = size.width / 120.0;

    final bookPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    void drawRoundedRect(Rect rect, double radius, Paint p) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius * scale)),
        p,
      );
    }

    // 左侧书架
    final leftX = centerX - 14 * scale;
    final bookY = centerY - 16 * scale;
    drawRoundedRect(
      Rect.fromLTWH(leftX, bookY, 16 * scale, 32 * scale),
      2.5,
      bookPaint,
    );

    // 白色横条
    canvas.drawRect(
      Rect.fromLTWH(leftX + 2 * scale, bookY + 9 * scale, 12 * scale, 2 * scale),
      whitePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(leftX + 2 * scale, bookY + 19 * scale, 12 * scale, 2 * scale),
      whitePaint,
    );

    // 右侧第一本书（倾斜 -10°）
    canvas.save();
    canvas.translate(centerX + 10 * scale, centerY);
    canvas.rotate(-0.1745);
    drawRoundedRect(
      Rect.fromLTWH(-4 * scale, -14 * scale, 8 * scale, 28 * scale),
      2,
      bookPaint,
    );
    canvas.restore();

    // 右侧第二本书（倾斜 -8°）
    canvas.save();
    canvas.translate(centerX + 20 * scale, centerY);
    canvas.rotate(-0.1396);
    drawRoundedRect(
      Rect.fromLTWH(-4 * scale, -14 * scale, 8 * scale, 28 * scale),
      2,
      bookPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
