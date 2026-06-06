import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../providers/books_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import 'confetti_painter.dart';

/// 庆祝动画覆盖层组件
/// 使用 OverlayEntry 方式插入到导航最上层
class CelebrationHelper {
  /// 触发庆祝动画
  static void trigger(BuildContext context) {
    _showOverlay(context);
  }

  static void _showOverlay(BuildContext context) {
    // 使用 root overlay 避免 Scaffold context 问题
    final overlay = Navigator.of(context).overlay!;
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _CelebrationWidget(
        onDismiss: () {
          entry.remove();
        },
        onShare: () {
          entry.remove();
          // 延迟一下等动画关闭
          Future.delayed(const Duration(milliseconds: 300), () {
            _doShare(context);
          });
        },
      ),
    );

    overlay.insert(entry);
  }

  static Future<void> _doShare(BuildContext context) async {
    final provider = context.read<BooksProvider>();
    final settings = context.read<SettingsProvider>();
    final count = provider.currentYearCount;
    final goal = settings.yearlyGoal;
    final year = DateTime.now().year;

    provider.markShareClicked();

    try {
      // 生成分享卡片图片
      final image = await _captureWidget(
        context,
        _buildShareImage(
          year: year,
          count: count,
          goal: goal,
        ),
      );

      if (image == null || !context.mounted) return;

      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/reading_achievement_$year.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());

      debugPrint('[CelebrationHelper] Sharing file: ${file.path}');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '🎉 我在 $year 年完成了阅读目标！已读完 $count 本，分享自「读书进度条」',
        ),
      );
    } catch (e) {
      debugPrint('[CelebrationHelper] 分享失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享失败，请重试')),
        );
      }
    }
  }

  static Future<ui.Image?> _captureWidget(
    BuildContext context,
    Widget widget,
  ) async {
    final key = GlobalKey();
    final overlay = Navigator.of(context).overlay!;

    final entry = OverlayEntry(
      builder: (_) => RepaintBoundary(
        key: key,
        child: widget,
      ),
    );

    overlay.insert(entry);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      return await boundary.toImage(pixelRatio: 3.0);
    } finally {
      entry.remove();
    }
  }

  static Widget _buildShareImage({
    required int year,
    required int count,
    required int goal,
  }) {
    return Material(
      child: Container(
        width: 1080,
        height: 1920,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE3E3),
              Color(0xFFFFF5F5),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📚', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 32),
            Text(
              '$year 阅读成就',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212529),
              ),
            ),
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF51CF66).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✅ ', style: TextStyle(fontSize: 36)),
                  Text(
                    '年度目标已达成',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF212529),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '本年度已读完',
                    style: TextStyle(fontSize: 24, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF51CF66),
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '本',
                    style: TextStyle(fontSize: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Container(
              height: 20,
              width: 400,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECEF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: goal > 0 ? (count / goal).clamp(0.0, 1.0) : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF51CF66), Color(0xFF69DB7C)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '已读完 $count / 目标 $goal 本',
              style: TextStyle(fontSize: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 100),
            Divider(indent: 100, endIndent: 100),
            const SizedBox(height: 24),
            Text(
              '来自「读书进度条」',
              style: TextStyle(fontSize: 18, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 庆祝动画 Widget（通过 OverlayEntry 展示）
class _CelebrationWidget extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onShare;

  const _CelebrationWidget({
    required this.onDismiss,
    required this.onShare,
  });

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget>
    with TickerProviderStateMixin {
  bool _showRingAnimation = false;
  bool _showConfetti = false;
  bool _showBanner = false;
  bool _dismissed = false;

  late AnimationController _ringController;

  late AnimationController _confettiController;
  List<ConfettiPiece> _confettiPieces = [];
  double _confettiValue = 0.0;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _confettiController.addListener(() {
      if (mounted) {
        setState(() {
          _confettiValue = _confettiController.value;
        });
        // 强制 OverlayEntry 重建
        if (widget != null) {
          // no-op, setState is enough
        }
      }
    });

    _ringController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _showRingAnimation) {
        _startConfetti();
      }
    });

    _confettiController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _showConfetti) {
        if (mounted) {
          setState(() => _showConfetti = false);
        }
      }
    });



    // 启动序列
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[CelebrationWidget] Starting celebration sequence');
      _startSequence();
    });
  }

  void _startSequence() {
    setState(() => _showRingAnimation = true);
    // 立即显示横幅（不等待进度环完成），让用户第一时间看到庆祝效果
    _showBanner = true;
    _generateConfetti();
    setState(() => _showConfetti = true);
    _confettiController.forward();
    // 进度环动画仍然播放（仅用于计时）
    _ringController.forward();
  }

  void _startConfetti() {
    // 现在全部在 _startSequence 中立即执行
  }

  void _generateConfetti() {
    final random = Random();
    const colors = [
      Color(0xFFFF6B6B),
      Color(0xFF51CF66),
      Color(0xFFFFD43B),
      Color(0xFF339AF0),
      Color(0xFFCC5DE8),
      Color(0xFFFF922B),
      Color(0xFF20C997),
      Color(0xFFF06595),
    ];

    _confettiPieces = List.generate(70, (i) {
      return ConfettiPiece(
        left: random.nextDouble() * 100,
        sizeW: 12 + random.nextDouble() * 12,
        sizeH: 14 + random.nextDouble() * 16,
        color: colors[random.nextInt(colors.length)],
        delay: random.nextDouble() * 0.6,
        duration: 1.8 + random.nextDouble() * 1.2,
        isCircle: random.nextBool(),
      );
    });
    debugPrint('[CelebrationWidget] Generated ${_confettiPieces.length} confetti pieces');
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _ringController.stop();
    _confettiController.stop();
    debugPrint('[CelebrationWidget] Dismissed by user tap');
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    debugPrint('[CelebrationWidget] build: showRing=$_showRingAnimation, showConfetti=$_showConfetti, showBanner=$_showBanner');

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 遮罩 + 点击跳过
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.12)),
            ),
          ),
          // 撒花粒子（层级最高）
        // 只要生成了粒子就显示（不依赖 _showConfetti）
        // 同时画一个全屏半透明测试层确认 CustomPaint 区域
        if (_confettiPieces.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  // 测试：画一个半透明覆盖层，确认 overlay 渲染正确
                  Container(color: Colors.blue.withValues(alpha: 0.05)),
                  // 撒花粒子
                  CustomPaint(
                    painter: ConfettiPainter(
                      pieces: _confettiPieces,
                      animationValue: _confettiValue,
                      height: screenSize.height,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 庆祝横幅
          if (_showBanner)
            Positioned(
              left: 24,
              right: 24,
              bottom: screenSize.height / 2 - 140,
              child: IgnorePointer(
                ignoring: false,
                child: _buildBanner(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    debugPrint('[CelebrationWidget] Building banner, showBanner=$_showBanner, confettiValue=$_confettiValue');
    return AnimatedOpacity(
      opacity: _showBanner ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      curve: const Cubic(0.34, 1.56, 0.64, 1),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD43B), Color(0xFFFF922B)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF922B).withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            const Text(
              '年度阅读目标达成！',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '你已完成本年度的阅读目标',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xD9FFFFFF),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                _dismissed = true;
                _ringController.stop();
                _confettiController.stop();
                widget.onShare();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  '📸 分享成就',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
