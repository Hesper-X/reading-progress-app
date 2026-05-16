import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';
import '../routes/app_routes.dart';

/// 启动页（3 秒后自动跳转首页）— 按设计稿 06 启动页.html 实现
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // 3 秒后跳转首页
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(
        const Duration(milliseconds: AppConstants.splashDurationMs),
        _navigateToHome,
      );
    });
  }

  void _navigateToHome() {
    if (mounted && context.mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
            // 主内容（动画渐入）
            FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
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
                    // App 名称 — 设计稿 28px
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
                    // Slogan
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
            ),
            // 底部加载动画 + 版本号
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: _LoadingIndicator(),
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

/// 底部加载动画（3 个跳动圆点 + "加载中..."）
class _LoadingIndicator extends StatefulWidget {
  @override
  State<_LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<_LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  double t = (_animController.value - index * 0.16) % 1.0;
                  if (t < 0) t += 1.0;
                  // 40% 的时间放大，60% 缩回
                  double scale = (t < 0.4)
                      ? 0.6 + (t / 0.4) * 0.4  // 0.6 → 1.0
                      : 1.0 - ((t - 0.4) / 0.6) * 0.4;  // 1.0 → 0.6
                  double opacity = (t < 0.4)
                      ? 0.5 + (t / 0.4) * 0.5
                      : 1.0 - ((t - 0.4) / 0.6) * 0.5;

                  return Padding(
                    padding: EdgeInsets.only(right: index < 2 ? 8.0 : 0),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: opacity),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          const Text(
            '加载中...',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xB3FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// 启动页环形进度条（65% 示例）
class _LaunchProgressPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 48.0;
    final strokeWidth = 7.0;

    // 未完成（灰色）
    final remainingPaint = Paint()
      ..color = AppColors.progressRemaining
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, remainingPaint);

    // 已完成（绿色，65%）
    final completedPaint = Paint()
      ..color = AppColors.success
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * 0.65;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      completedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 启动页书架 + 书籍图标 — 按设计稿 06 启动页.html SVG 实现
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
    final bookStrokePaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    void drawRoundedRect(Rect rect, double radius, Paint p) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius * scale)),
        p,
      );
    }

    // 左侧书架（主轴居中）
    // SVG 坐标 (46, 46, 16, 32) → 以 120 为基准
    final leftX = centerX - 14 * scale;
    final bookY = centerY - 16 * scale;

    // 书架主体
    drawRoundedRect(
      Rect.fromLTWH(leftX, bookY, 16 * scale, 32 * scale),
      2.5,
      bookPaint,
    );

    // 书架白色横条
    whitePaint.style = PaintingStyle.fill;
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
    final r1Center = Offset(centerX + 10 * scale, centerY);
    canvas.translate(r1Center.dx, r1Center.dy);
    canvas.rotate(-0.1745); // -10°
    drawRoundedRect(
      Rect.fromLTWH(-4 * scale, -14 * scale, 8 * scale, 28 * scale),
      2,
      bookPaint,
    );
    canvas.restore();

    // 右侧第二本书（倾斜 -8°）
    canvas.save();
    final r2Center = Offset(centerX + 20 * scale, centerY);
    canvas.translate(r2Center.dx, r2Center.dy);
    canvas.rotate(-0.1396); // -8°
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
