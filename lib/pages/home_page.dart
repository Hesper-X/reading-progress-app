import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../providers/filter_provider.dart';
import '../theme/colors.dart';
import '../routes/app_routes.dart';
import '../widgets/book_cover.dart';

/// 环形进度条组件 — 支持庆祝动画模式
class CircularProgress extends StatefulWidget {
  final double progress; // 0.0 ~ 1.0
  final double diameter;
  final double strokeWidth;
  final bool isCelebrating;
  final double ringAnimationValue; // 0.0 ~ 1.0，庆祝时驱动进度环加速

  const CircularProgress({
    super.key,
    required this.progress,
    this.diameter = 180,
    this.strokeWidth = 12,
    this.isCelebrating = false,
    this.ringAnimationValue = 1.0,
  });

  @override
  State<CircularProgress> createState() => _CircularProgressState();
}

class _CircularProgressState extends State<CircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _normalController;
  late Animation<double> _normalAnimation;
  double _previousProgress = 0.0;
  double _animatedProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _normalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _normalAnimation = CurvedAnimation(
      parent: _normalController,
      curve: Curves.easeOut,
    );
    _normalController.addListener(() {
      if (mounted) {
        setState(() {
          _animatedProgress =
              _previousProgress +
              (widget.progress - _previousProgress) * _normalAnimation.value;
        });
      }
    });
    // 首次构建直接显示目标值
    _animatedProgress = widget.progress;
  }

  @override
  void didUpdateWidget(CircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress && !widget.isCelebrating) {
      _previousProgress = _animatedProgress;
      _normalController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _normalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayProgress = widget.isCelebrating
        ? widget.ringAnimationValue
        : _animatedProgress;

    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(widget.diameter, widget.diameter),
            painter: _ProgressPainter(
              progress: displayProgress,
              strokeWidth: widget.strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(displayProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: widget.isCelebrating && displayProgress >= 1.0
                      ? AppColors.success
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Consumer<BooksProvider>(
                builder: (context, provider, _) {
                  return Text(
                    '已读完 ${provider.currentYearCount} 本',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _ProgressPainter({required this.progress, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 未完成环
    final bgPaint = Paint()
      ..color = AppColors.progressRemaining
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 已完成环
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = AppColors.success
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 首页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _shareEntryShown = false;
  bool _celebrationClosed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkShareEntry();
    });
  }

  void _checkShareEntry() {
    if (!mounted) return;
    final provider = context.read<BooksProvider>();
    setState(() {
      _shareEntryShown = provider.shouldShowShareEntry();
    });
  }

  void _closeCelebration() {
    if (!mounted) return;
    final provider = context.read<BooksProvider>();
    provider.markCelebrationTriggered();
    setState(() => _celebrationClosed = true);
  }

  @override
  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1),
        ),
        title: Text(
          '$year 年读书进度',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Consumer<BooksProvider>(
        builder: (context, provider, _) {
          final showCelebration =
              provider.celebrationAchieved &&
              !provider.celebrationTriggered &&
              !_celebrationClosed;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkShareEntry();
          });
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final readingBooks = provider.readingBooks;
          return Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: CircularProgress(progress: provider.progress),
                    ),
                    const SizedBox(height: 12),
                    // V3.0 设计：目标/已读/在读/想读 四数字行
                    _GoalRow(provider: provider),
                    const SizedBox(height: 20),
                    _ReadingSection(books: readingBooks),
                    const SizedBox(height: 24),
                    // V3.0：庆祝横幅文案改为目标达成→分享Tab
              if (_shareEntryShown)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () {
                      try {
                        context.read<BooksProvider>().markShareClicked();
                        // 跳转到分享Tab，筛选锁定当年+无月份
                        context.read<FilterProvider>().resetToDefault();
                      } catch (_) {}
                      Navigator.pushNamed(context, AppRoutes.share);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD43B), Color(0xFFFF922B)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          '🎉 年度目标达成！分享我的阅读成果 →',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                  // 底部操作按钮 — V3.0设计
                  _HomeActionButtons(provider: provider),
                ],
              ),
            ),
              if (showCelebration)
                _CelebrationOverlay(onClose: _closeCelebration),
            ],
          );
        },
      ),

    );
  }
}

/// 目标/已读/在读/想读 四数字行
class _GoalRow extends StatelessWidget {
  final BooksProvider provider;

  const _GoalRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GoalItem(num: '${provider.yearlyGoal}', label: '目标'),
          const SizedBox(width: 32),
          _GoalItem(num: '${provider.currentYearCount}', label: '已读'),
          const SizedBox(width: 32),
          _GoalItem(num: '${provider.readingBooks.length}', label: '在读'),
          const SizedBox(width: 32),
          _GoalItem(num: '${provider.wishBooks.length}', label: '想读'),
        ],
      ),
    );
  }
}

class _GoalItem extends StatelessWidget {
  final String num;
  final String label;

  const _GoalItem({required this.num, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          num,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 当前在读卡片区域
class _ReadingSection extends StatelessWidget {
  final List<Book> books;

  const _ReadingSection({required this.books});

  @override
  Widget build(BuildContext context) {
    final displayBooks = books.take(2).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📉', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              const Text(
                '当前在读',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (books.isNotEmpty) ...[
            ...displayBooks.map(
              (book) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReadingCard(book: book),
              ),
            ),
          ] else
            _EmptyHint(),
        ],
      ),
    );
  }
}

/// 在读卡片 — 设计稿V3.0：📖图标 + 标题/作者 + 已读天数 + › 箭头同一行
class _ReadingCard extends StatelessWidget {
  final Book book;

  const _ReadingCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.library,
          arguments: {'tab': 'reading'},
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF5F5), Color(0xFFFFE3E3)],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            BookCover(
              coverPath: book.coverPath,
              width: 44,
              height: 56,
              borderRadius: 6,
              reading: true,
            ),
            const SizedBox(width: 14),
            // 标题 + 作者（flex: 1撑开，让已读天数靠右）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // V3.2 右侧：编辑按钮 + 已读天数 + 箭头
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // V3.2 编辑按钮（点击跳转到 /add 路由编辑）
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.add, arguments: book),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFC9C9), width: 1),
                        color: const Color(0xFFFFF5F5),
                      ),
                      child: const Text('编辑',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFFF6B6B))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '已读 ${book.elapsedDays} 天',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '›',
                    style: TextStyle(fontSize: 18, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ 内嵌庆祝组件 ============

class _CelebrationOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const _CelebrationOverlay({required this.onClose});

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _showBanner = false;
  bool _dismissed = false;
  List<_ConfettiSpec> _specs = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
      ..addListener(() { if (mounted) setState(() {}); });
    _generateSpecs();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showBanner = true);
    });
  }

  void _generateSpecs() {
    final random = Random();
    const colors = [
      Color(0xFFFF6B6B), Color(0xFF51CF66), Color(0xFFFFD43B),
      Color(0xFF339AF0), Color(0xFFCC5DE8), Color(0xFFFF922B),
      Color(0xFF20C997), Color(0xFFF06595),
    ];
    _specs = List.generate(70, (i) => _ConfettiSpec(
      leftPct: random.nextDouble() * 100,
      sizeW: 8 + random.nextDouble() * 14,
      sizeH: 10 + random.nextDouble() * 16,
      color: colors[random.nextInt(colors.length)],
      delay: random.nextDouble() * 0.6,
      isCircle: random.nextBool(),
    ));
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _controller.stop();
    widget.onClose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _controller.value;
    return Positioned.fill(
      child: GestureDetector(
        onTap: _dismiss,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(color: Colors.black.withValues(alpha: 0.12)),
            if (_showBanner)
              Positioned(
                left: 24,
                right: 24,
                top: MediaQuery.of(context).size.height * 0.38,
                child: IgnorePointer(ignoring: false, child: _buildBanner()),
              ),
            // 撒花粒子 — 直接在 build 中生成，_controller.addListener 触发 setState 驱动动画
            ..._buildConfetti(context, t),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConfetti(BuildContext context, double t) {
    // 用 MediaQuery 获取屏幕高度作为容器高度（接近 body 高度）
    final containerH = MediaQuery.of(context).size.height;
    final containerW = MediaQuery.of(context).size.width;
    // 总行程确保远超容器高度，让粒子必定掉出底部被 clip 裁切
    final totalTravel = containerH * 1.5;
    return _specs.map((spec) {
      final adjusted = ((t - spec.delay) / (1.0 - spec.delay)).clamp(0.0, 1.0);
      if (adjusted <= 0) return const SizedBox.shrink();
      // 从 -sizeH 掉到 containerH + sizeH（超出底部后被 Clip.hardEdge 裁切）
      final top = -spec.sizeH + adjusted * totalTravel;
      // 用 top 位置决定淡出：距离底部 150px 开始淡出
      final opacity = ((containerH - top) / 150.0).clamp(0.0, 1.0);
      if (opacity <= 0) return const SizedBox.shrink();
      return Positioned(
        left: spec.leftPct * containerW / 100 - spec.sizeW / 2,
        top: top,
        child: Transform.rotate(
          angle: t * 4 * pi,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: spec.sizeW,
              height: spec.sizeH,
              decoration: BoxDecoration(
                color: spec.color,
                borderRadius: spec.isCircle
                    ? BorderRadius.circular(99)
                    : BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBanner() {
    return AnimatedOpacity(
      opacity: _showBanner ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
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
              style: TextStyle(fontSize: 14, color: Color(0xD9FFFFFF)),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                _dismissed = true;
                _controller.stop();
                widget.onClose();
                // 跳转到分享Tab，筛选锁定当年+无月份
                context.read<FilterProvider>().resetToDefault();
                Navigator.pushNamed(context, AppRoutes.share);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
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

  Future<void> _doShare(BuildContext context) async {
    final provider = context.read<BooksProvider>();
    final count = provider.currentYearCount;
    final goal = provider.yearlyGoal;
    final year = DateTime.now().year;
    provider.markShareClicked();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '🎉 我在 $year 年完成了阅读目标！已读完 $count 本（目标 $goal 本），分享自「读书进度条」',
        ),
      );
    } catch (e) {
      debugPrint('分享失败: $e');
    }
  }
}

// ============ 撒花粒子 ============

/// 一粒撒花的固定参数
class _ConfettiSpec {
  final double leftPct;
  final double sizeW;
  final double sizeH;
  final Color color;
  final double delay;
  final bool isCircle;

  _ConfettiSpec({
    required this.leftPct,
    required this.sizeW,
    required this.sizeH,
    required this.color,
    required this.delay,
    required this.isCircle,
  });
}

/// V3.0 首页底部操作按钮
class _HomeActionButtons extends StatelessWidget {
  final BooksProvider provider;

  const _HomeActionButtons({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.wish),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(21),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('读书清单', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.add),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(21),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('开始阅读', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态提示
class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 8),
          Icon(Icons.menu_book, size: 80, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            '还没有在读的书',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '点击右下角 [+开始阅读] 记录第一本在读的书',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
